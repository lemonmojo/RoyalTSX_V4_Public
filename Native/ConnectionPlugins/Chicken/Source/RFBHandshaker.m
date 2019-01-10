/* RFBHandshaker.m created by helmut on Tue 16-Jun-1998 */

/* Copyright (C) 1998-2000  Helmut Maierhofer <helmut.maierhofer@chello.at>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#import "RFBHandshaker.h"
#import "RFBServerInitReader.h"
#import "CARD8Reader.h"
#import "CARD32Reader.h"
#import "ByteBlockReader.h"
#import "RFBStringReader.h"

/* This handles the handshaking messages from the server. */
@implementation RFBHandshaker

- (id)initWithConnection: (RFBConnection *)aConnection;
{
	if (self = [super init]) {
        connection = aConnection;
        connFailedReader = [[RFBStringReader alloc] initTarget:self action:@selector(connFailed:) connection:connection];
		challengeReader = [[ByteBlockReader alloc] initTarget:self action:@selector(challenge:) size:CHALLENGESIZE];
		authResultReader = [[CARD32Reader alloc] initTarget:self action:@selector(setAuthResult:)];
        
        // ARD Auth
        ardGeneratorReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setArdGenerator:) size:2];
        ardKeyLengthReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setArdKeyLength:) size:2];
        
        // MS-Logon II
        mslGeneratorReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setMslGenerator:) size:8];
        mslModReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setMslMod:) size:8];
        mslRespReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setMslResp:) size:8];
        
        serverInitReader = nil;
	}
    return self;
}

- (void)dealloc
{
    if (connFailedReader) {
        [connFailedReader release];
        connFailedReader = nil;
    }
    
    if (challengeReader) {
        [challengeReader release];
        challengeReader = nil;
    }
    
    if (authResultReader) {
        [authResultReader release];
        authResultReader = nil;
    }
    
    if (mslGeneratorReader) {
        [mslGeneratorReader release];
        mslGeneratorReader = nil;
    }
    
    if (mslModReader) {
        [mslModReader release];
        mslModReader = nil;
    }
    
    if (mslRespReader) {
        [mslRespReader release];
        mslRespReader = nil;
    }
    
    if (serverInitReader) {
        [serverInitReader release];
        serverInitReader = nil;
    }
    
    if (vncAuthChallenge) {
        [vncAuthChallenge release];
        vncAuthChallenge = nil;
    }
    
    if (ardGeneratorReader) {
        [ardGeneratorReader release];
        ardGeneratorReader = nil;
    }
    
    if (ardKeyLengthReader) {
        [ardKeyLengthReader release];
        ardKeyLengthReader = nil;
    }
    
    if (ardPrimeReader) {
        [ardPrimeReader release];
        ardPrimeReader = nil;
    }
    
    if (ardPeerKeyReader) {
        [ardPeerKeyReader release];
        ardPeerKeyReader = nil;
    }
    
    if (mslGenerator) {
        [mslGenerator release];
        mslGenerator = nil;
    }
    
    if (mslMod) {
        [mslMod release];
        mslMod = nil;
    }
    
    if (mslResp) {
        [mslResp release];
        mslResp = nil;
    }
    
    [super dealloc];
}

- (void)handshake
{
    char clientData[sz_rfbProtocolVersionMsg + 1];
	int protocolMinorVersion = [connection protocolMinorVersion];

	sprintf(clientData, rfbProtocolVersionFormat, rfbProtocolMajorVersion, protocolMinorVersion);
    [connection writeBytes:(unsigned char*)clientData length:sz_rfbProtocolVersionMsg];
		
	if (protocolMinorVersion >= 7) {
        CARD8Reader *authCountReader;

		authCountReader = [[CARD8Reader alloc] initTarget:self action:@selector(setAuthCount:)];
		[connection setReader:authCountReader];
        [authCountReader release];
    } else {
        CARD32Reader    *authTypeReader;

		authTypeReader = [[CARD32Reader alloc] initTarget:self action:@selector(setAuthType:)];
		[connection setReader:authTypeReader];
        [authTypeReader release];
    }
}

- (void)sendClientInit
{
    unsigned char shared = [connection connectShared] ? 1 : 0;

    [connection writeBytes:&shared length:1];
    [serverInitReader release];
    serverInitReader = [[RFBServerInitReader alloc] initWithConnection: connection andHandshaker: self];
    [serverInitReader readServerInit];
}

// Protocol 3.7+
- (void)setAuthCount:(NSNumber*)authCount {
	if ([authCount intValue] == 0) {
        [connFailedReader readString];
	}
	else {
        ByteBlockReader *authTypeArrayReader;
		authTypeArrayReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setAuthArray:) size:[authCount intValue]];
		[connection setReader:authTypeArrayReader];
        [authTypeArrayReader release];
	}
}

// Protocol 3.7+
- (void)setAuthArray:(NSData*)authTypeArray {
	// The server is giving us a choice of auth types, we'll take the first one that we can handle
	int index=0;
	const char *bytes=[authTypeArray bytes];
	unsigned char availableAuthType=0;
	NSString *errorStr = nil;
	
	while (index < [authTypeArray length]) {
		unsigned char availableAuthType = bytes[index++];
		
		switch (availableAuthType) {
			case rfbNoAuth: {
                selectedAuthType = availableAuthType;
				[connection writeBytes:&availableAuthType length:1];
				
				if ([connection protocolMinorVersion] >= 8) // For 3.8+ we need to get a result back from the server
					[connection setReader: authResultReader];
				else // For 3.7 we continue on with Client Init
					[self sendClientInit];
				
				return;
			}
			case rfbVncAuth: {
                selectedAuthType = availableAuthType;
				[connection writeBytes:&availableAuthType length:1];
				[connection setReader:challengeReader];
				return;
			}
            case rfbArdAuth:
                selectedAuthType = availableAuthType;
                [connection writeBytes:&availableAuthType length:1];
                [self performARDAuth];
                return;
            case rfbAuthMsLogon:
                selectedAuthType = availableAuthType;
                [connection writeBytes:&availableAuthType length:1];
                [self performMSLogonAuth];
                return;
			default: {
				if (!errorStr)
					errorStr = [NSString stringWithFormat:ChickenVncFrameworkLocalizedString( @"UnknownAuthType", nil ),
						[NSNumber numberWithChar:availableAuthType]]; 
				else
					errorStr = [errorStr stringByAppendingFormat:@", %@", [NSNumber numberWithChar:availableAuthType]];

			}
		}
	}

	// No valid auth type found
	availableAuthType= 0;
	[connection writeBytes:&availableAuthType length:1];
    
	[connection terminateConnection:errorStr];
}

- (void)setAuthType:(NSNumber*)authType
{
    switch([authType unsignedIntValue]) {
        case rfbConnFailed:
            [connFailedReader readString];
            break;
        case rfbNoAuth:
            [self sendClientInit];
            break;
        case rfbVncAuth:
            [connection setReader:challengeReader];
            break;
        case rfbArdAuth:
            [self performARDAuth];
            break;
        case rfbUltra:
            [self performMSLogonAuth];
            break;
        default:
		{
			NSString *errorStr = ChickenVncFrameworkLocalizedString( @"UnknownAuthType", nil );
			errorStr = [NSString stringWithFormat:errorStr, authType];
            [connection terminateConnection:errorStr];
            break;
		}
    }
}

- (void)challenge:(NSData*)theChallenge
{
    unsigned char bytes[CHALLENGESIZE];

    if ([connection password] == nil) {
        [connection promptForPassword];
        [vncAuthChallenge autorelease];
        /* Note that theChallenge uses strictly temporary memory, so we can't
         * just retain, we have to copy. */
        vncAuthChallenge = [[NSData dataWithData:theChallenge] copy];
        return;
    }

    [theChallenge getBytes:bytes length:CHALLENGESIZE];
    vncEncryptBytes(bytes, (char*)[[connection password] UTF8String]);
    [connection writeBytes:bytes length:CHALLENGESIZE];
    [connection setReader:authResultReader];
    triedPassword = YES;
}

- (void)performARDAuth
{
    [connection setReader:ardGeneratorReader];
}

- (void)setArdGenerator:(NSData*)theGenerator
{
    //NSLog(@"Chicken: GENERATOR READ");
    ardGenerator = [theGenerator copy];
    //NSLog(@"Chicken: GENERATOR: %@", ardGenerator.description);
    [connection setReader:ardKeyLengthReader];
}

- (void)setArdKeyLength:(NSData*)theKeyLength
{
    //NSLog(@"Chicken: KEY LENGTH READ");
    //NSLog(@"Chicken: KEY LENGTH ARR: %@", theKeyLength.description);
    [theKeyLength getBytes:ardKeyLengthArr length:2];
    ardKeyLength = (int)((ardKeyLengthArr[0] << 8) | ardKeyLengthArr[1]);
    //NSLog(@"Chicken: KEY LENGTH: %i", ardKeyLength);
    
    ardPrimeReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setArdPrime:) size:ardKeyLength];
    [connection setReader:ardPrimeReader];
}

- (void)setArdPrime:(NSData*)thePrime
{
    //NSLog(@"Chicken: PRIME READ");
    ardPrime = [thePrime copy];
    
    ardPeerKeyReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setArdPeerKey:) size:ardKeyLength];
    [connection setReader:ardPeerKeyReader];
}

- (void)setArdPeerKey:(NSData*)thePeerKey
{
    //NSLog(@"Chicken: PEER KEY READ");
    ardPeerKey = [thePeerKey copy];
    [self performArdDH];
}

- (void)performArdDH
{
    NSNumber *ardKeyLengthNum = [NSNumber numberWithInt:ardKeyLength];
    
    NSArray *ardResult = [self performARDAuthWithPrime:ardPrime
                                             generator:ardGenerator
                                               peerKey:ardPeerKey
                                             keyLength:ardKeyLengthNum];
    
    if (ardResult) {
        NSData *ciphertextData = [ardResult objectAtIndex:0];
        NSData *publicKeyData  = [ardResult objectAtIndex:1];
        
        size_t ciphertextSize = [ciphertextData length];
        unsigned char* ciphertext = (unsigned char*)malloc(ciphertextSize);
        [ciphertextData getBytes:ciphertext length:ciphertextSize];
        
        size_t publicKeySize = [publicKeyData length];
        unsigned char* publicKey = (unsigned char*)malloc(publicKeySize);
        [publicKeyData getBytes:publicKey length:publicKeySize];
        
        /* NSLog(@"CIPHER:");
        for (int i = 0; i < ciphertextSize; i++) {
            NSLog(@"%i", ciphertext[i]);
        }
        
        NSLog(@"PUBLICKEY:");
        for (int i = 0; i < publicKeySize; i++) {
            NSLog(@"%i", publicKey[i]);
        } */
        
        [connection writeBytes:ciphertext length:ciphertextSize];
        [connection writeBytes:publicKey length:publicKeySize];
    }
    
    if (ardPeerKey) {
        [ardPeerKey release];
        ardPeerKey = nil;
    }
    
    if (ardPrime) {
        [ardPrime release];
        ardPrime = nil;
    }
    
    [connection setReader:authResultReader];
    triedArdAuth = YES;
}

- (void)performMSLogonAuth
{
    //NSLog(@"Chicken: MS LOGON AUTH");
    [connection setReader:mslGeneratorReader];
}

- (void)setMslGenerator:(NSData*)theGenerator
{
    //NSLog(@"Chicken: GENERATOR READ");
    mslGenerator = [theGenerator copy];
    //NSLog(@"Chicken: GENERATOR: %@", mslGenerator.description);
    [connection setReader:mslModReader];
}

- (void)setMslMod:(NSData*)theMod
{
    //NSLog(@"Chicken: MOD READ");
    mslMod = [theMod copy];
    //NSLog(@"Chicken: MOD: %@", theMod.description);
    [connection setReader:mslRespReader];
}

- (void)setMslResp:(NSData*)theResp
{
    //NSLog(@"Chicken: RESP READ");
    mslResp = [theResp copy];
    //NSLog(@"Chicken: RESP: %@", theResp.description);
    
    [self performMsDH];
}


- (void)performMsDH
{
    //NSLog(@"Chicken: PERFORM MS DH");
    
    NSArray *ardResult = [self performMSLogon2AuthWithGenerator:mslGenerator
                                                            mod:mslMod
                                                           resp:mslResp];
    
    if (ardResult) {
        NSData *publicKeyData  = [ardResult objectAtIndex:0];
        NSData *credentialsData   = [ardResult objectAtIndex:1];
        
        size_t publicKeySize = [publicKeyData length];
        unsigned char* publicKey = (unsigned char*)malloc(publicKeySize);
        [publicKeyData getBytes:publicKey length:publicKeySize];
        
        size_t credentialsSize = [credentialsData length];
        unsigned char* credentials = (unsigned char*)malloc(credentialsSize);
        [credentialsData getBytes:credentials length:credentialsSize];
        
        //NSLog(@"Chicken: MSL2 Writing Public Key");
        [connection writeBytes:publicKey length:publicKeySize];
        
        //NSLog(@"Chicken: MSL2 Writing Credentials");
        [connection writeBytes:credentials length:credentialsSize];
    }
    
    if (mslGenerator) {
        [mslGenerator release];
        mslGenerator = nil;
    }
    
    if (mslMod) {
        [mslMod release];
        mslMod = nil;
    }
    
    if (mslResp) {
        [mslResp release];
        mslResp = nil;
    }
    
    [connection setReader:authResultReader];
    triedMSL2Auth = YES;
}

- (NSArray*)performARDAuthWithPrime:(NSData*)prime generator:(NSData*)generator peerKey:(NSData*)peerKey keyLength:(NSNumber*)keyLength
{
    id ctrl = [self chickenVncViewController];
    
    NSArray *ret = [ctrl performARDAuthWithPrime:prime
                                       generator:generator
                                         peerKey:peerKey
                                       keyLength:keyLength];
    
    return ret;
}

- (NSArray*)performMSLogon2AuthWithGenerator:(NSData*)generator mod:(NSData*)mod resp:(NSData*)resp
{
    id ctrl = [self chickenVncViewController];
    
    NSArray *ret = [ctrl performMSLogon2AuthWithGenerator:generator
                                                      mod:mod
                                                     resp:resp];
    
    return ret;
}

- (id)chickenVncViewController
{
    id delegate = [[connection session] delegate];
    
    return delegate;
}

- (void)gotPassword
{
    if (vncAuthChallenge) {
        [self challenge:vncAuthChallenge];
        [vncAuthChallenge release];
        vncAuthChallenge = nil;
    }
}

- (void)setAuthResult:(NSNumber*)theResult
{
    NSString *errorStr;
    int protocolMinorVersion = [connection protocolMinorVersion];
    
    //NSLog(@"Chicken: Auth Result: %i", [theResult unsignedIntValue]);
    
    switch([theResult unsignedIntValue]) {
        case rfbVncAuthOK:
            authError = NO;
            
            [self sendClientInit];
            return;
        case rfbVncAuthFailed:
            authError = YES;
            
            if (protocolMinorVersion >= 8) {
                 // 3.8+ We get an error return string (unlocalized)
                [connFailedReader readString];
                return;
            }
            else {
                errorStr = @"";
            }
            break;
        case rfbVncAuthTooMany:
            authError = NO;
            /* According to the spec, this should never happen, because we don't
             * specify the Tight security type. */
            errorStr = ChickenVncFrameworkLocalizedString(@"AuthenticationFailedTooMany", nil);
            [connection terminateConnection:errorStr];
            return;
        default:
            authError = NO;
            errorStr = ChickenVncFrameworkLocalizedString(@"UnknownAuthResult", nil);
            errorStr = [NSString stringWithFormat:errorStr, theResult];
            break;
    }
    
    if (authError) {
        [connection authenticationFailedFx:errorStr];
    } else if (triedPassword) {
        [connection authenticationFailed:errorStr];
    } else {
        errorStr = ChickenVncFrameworkLocalizedString(@"AuthenticationFailed", nil);
        [connection terminateConnection:errorStr];
    }
}

- (void)setServerInit:(ServerInitMessage*)serverMsg
{
    [connection start:serverMsg];
}

- (void)connFailed:(NSString*)theReason
{
    NSString *errorStr;

    errorStr = [NSString stringWithFormat:@"%@: %@",
                        ChickenVncFrameworkLocalizedString(@"ServerReports", nil),
                        theReason];
    
    if (authError) {
        [connection authenticationFailedFx:errorStr];
    } else if (triedPassword) {
        [connection authenticationFailed:errorStr];
    } else {
        [connection terminateConnection:errorStr];
    }
}

@end
