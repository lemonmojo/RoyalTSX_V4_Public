/* RFBHandshaker.h created by helmut on Tue 16-Jun-1998 */

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

#import <AppKit/AppKit.h>
#import "RFBConnection.h"
#import "vncauth.h"

@class ServerInitMessage;

@interface RFBHandshaker : NSObject
{
    RFBConnection   *connection;
    id	connFailedReader;
    id	challengeReader;
    id	authResultReader;
    id	serverInitReader;
    
    unsigned char selectedAuthType;
    
    id ardGeneratorReader;
    id ardKeyLengthReader;
    id ardPrimeReader;
    id ardPeerKeyReader;
    
    id mslGeneratorReader;
    id mslModReader;
    id mslRespReader;
    
    BOOL    authError;
    BOOL    triedPassword;
    BOOL    triedArdAuth;
    BOOL    triedMSL2Auth;
    NSData  *vncAuthChallenge;
    
    NSData          *ardGenerator;
    unsigned char   ardKeyLengthArr[2];
    int             ardKeyLength;
    NSData          *ardPrime;
    NSData          *ardPeerKey;
    
    NSData          *mslGenerator;
    NSData          *mslMod;
    NSData          *mslResp;
}

- (id)initWithConnection: (RFBConnection *)aConnection;

- (void)handshake;
- (void)setServerInit: (ServerInitMessage *)serverMsg;

- (void)gotPassword;

@end
