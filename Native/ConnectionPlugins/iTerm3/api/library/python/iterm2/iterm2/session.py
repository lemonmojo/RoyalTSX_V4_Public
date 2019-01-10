"""Provides classes for interacting with iTerm2 sessions."""
import asyncio

import iterm2.app
import iterm2.connection
import iterm2.notifications
import iterm2.profile
import iterm2.rpc
import iterm2.util

class SplitPaneException(Exception):
    """Something went wrong when trying to split a pane."""
    pass

class Splitter:
    """A container of split pane sessions where the dividers are all aligned the same way.

    :ivar vertical: Whether the split pane dividers in this Splitter are vertical
      or horizontal.
    """
    def __init__(self, vertical=False):
        """
        :param vertical: Bool. If true, the divider is vertical, else horizontal.
        """
        self.vertical = vertical
        # Elements are either Splitter or Session
        self.__children = []
        # Elements are Session
        self.__sessions = []

    @staticmethod
    def from_node(node, connection):
        """Creates a new Splitter from a node.

        node: iterm2.api_pb2.ListSessionsResponse.SplitTreeNode
        connection: :class:`Connection`

        :returns: A new Splitter.
        """
        splitter = Splitter(node.vertical)
        for link in node.links:
            if link.HasField("session"):
                session = Session(connection, link)
                splitter.add_child(session)
            else:
                subsplit = Splitter.from_node(link.node, connection)
                splitter.add_child(subsplit)
        return splitter

    def add_child(self, child):
        """
        Adds one or more new sessions to a splitter.

        child: A Session or a Splitter.
        """
        self.__children.append(child)
        if isinstance(child, Session):
            self.__sessions.append(child)
        else:
            self.__sessions.extend(child.sessions)

    @property
    def children(self):
        """
        :returns: This splitter's children. A list of :class:`Session` objects.
        """
        return self.__children

    @property
    def sessions(self):
        """
        :returns: All sessions in this splitter and all nested splitters. A list of
          :class:`Session` objects.
        """
        return self.__sessions

    def pretty_str(self, indent=""):
        """
        :returns: A string describing this splitter. Has newlines.
        """
        string_value = indent + "Splitter %s\n" % (
            "|" if self.vertical else "-")
        for child in self.__children:
            string_value += child.pretty_str("  " + indent)
        return string_value

    def update_session(self, session):
        """
        Finds a session with the same ID as session. If it exists, replace the reference with
        session.

        :returns: True if the update occurred.
        """
        i = 0
        for child in self.__children:
            if isinstance(child, Session) and child.session_id == session.session_id:
                self.__children[i] = session

                # Update the entry in self.__sessions
                for j in range(len(self.__sessions)):
                    if self.__sessions[j].session_id == session.session_id:
                        self.__sessions[j] = session
                        break

                return True
            elif isinstance(child, Splitter):
                if child.update_session(session):
                    return True
            i += 1
        return False

class Session:
    """
    Represents an iTerm2 session.
    """

    @staticmethod
    def active_proxy(connection):
        """
        Use this to register notifications against the currently active session.

        :returns: A proxy for the currently active session.
        """
        return ProxySession(connection, "active")

    @staticmethod
    def all_proxy(connection):
        """
        Use this to register notifications against all sessions, including those
        not yet created.

        :returns: A proxy for all sessions.
        """
        return ProxySession(connection, "all")

    def __init__(self, connection, link):
        """
        connection: :class:`Connection`
        link: iterm2.api_pb2.ListSessionsResponse.SplitTreeNode.SplitTreeLink
        """
        self.connection = connection

        if link is not None:
            self.__session_id = link.session.unique_identifier
            self.frame = link.session.frame
            self.grid_size = link.session.grid_size
            self.name = link.session.title

    def __repr__(self):
        return "<Session name=%s id=%s>" % (self.name, self.__session_id)

    def update_from(self, session):
        """Replace internal state with that of another session."""
        self.frame = session.frame
        self.grid_size = session.grid_size
        self.name = session.name

    def pretty_str(self, indent=""):
        """
        :returns: A string describing the session.
        """
        return indent + "Session \"%s\" id=%s %s frame=%s\n" % (
            self.name,
            self.__session_id,
            iterm2.util.size_str(self.grid_size),
            iterm2.util.frame_str(self.frame))

    @property
    def session_id(self):
        """
        :returns: the globally unique identifier for this session.
        """
        return self.__session_id

    def get_keystroke_reader(self):
        """
        Provides a nice interface for observing a sequence of keystrokes.

        :returns: a keystroke reader, a :class:`Session.KeystrokeReader`.

        :Example:

          async with session.get_keystroke_reader() as reader:
            while condition():
              handle_keystrokes(reader.get())

        .. note:: Each call to reader.get() returns an array of new keystrokes.
        """
        return self.KeystrokeReader(self.connection, self.__session_id)

    def get_screen_streamer(self, want_contents=True):
        """
        Provides a nice interface for receiving updates to the screne.

        The screen is the mutable part of a session (its last lines, excluding
        scrollback history).

        :returns: A :class:`Session.ScreenStreamer`.
        """
        return self.ScreenStreamer(self.connection, self.__session_id, want_contents=want_contents)

    async def async_send_text(self, text):
        """
        Send text as though the user had typed it.

        :param text: The text to send.
        """
        await iterm2.rpc.async_send_text(self.connection, self.__session_id, text)

    async def async_split_pane(self, vertical=False, before=False, profile=None):
        """
        Splits the pane, creating a new session.

        :param vertical: Bool. If true, the divider is vertical, else horizontal.
        :param before: Bool, whether the new session should be left/above the existing one.
        :param profile: The profile name to use. None for the default profile.

        :returns: New iterm.session.Session.

        :throws: SplitPaneException if something goes wrong.
        """
        result = await iterm2.rpc.async_split_pane(
            self.connection,
            self.__session_id,
            vertical,
            before,
            profile)
        if result.split_pane_response.status == iterm2.api_pb2.SplitPaneResponse.Status.Value("OK"):
            new_session_id = result.split_pane_response.session_id[0]
            app = await iterm2.app.async_get_app(self.connection)
            await app.async_refresh()
            return app.get_session_by_id(new_session_id)
        else:
            raise SplitPaneException(
                iterm2.api_pb2.SplitPaneResponse.Status.Name(result.split_pane_response.status))

    async def async_read_keystroke(self):
        """
        Blocks until a keystroke is received. Returns a KeystrokeNotification.

        See also get_keystroke_reader().

        :returns: :class:`api_pb2.KeystrokeNotification`
        """
        future = asyncio.Future()
        async def async_on_keystroke(_connection, message):
            """Called on keystroke to finish the future so async_read_keystroke will return."""
            future.set_result(message)

        token = await iterm2.notifications.async_subscribe_to_keystroke_notification(
            self.connection,
            async_on_keystroke,
            self.__session_id)
        await self.connection.async_dispatch_until_future(future)
        await iterm2.notifications.async_unsubscribe(self.connection, token)
        return future.result()

    async def async_wait_for_screen_update(self):
        """
        Blocks until the screen contents change.

        :returns: iterm2.api_pb2.ScreenUpdateNotification
        """
        future = asyncio.Future()
        async def async_on_update(_connection, message):
            """Called when the screen changes to finish the future so async_wait_for_screen_update
            will return."""
            future.set_result(message)

        token = await iterm2.notifications.async_subscribe_to_screen_update_notification(
            self.connection,
            async_on_update,
            self.__session_id)
        await self.connection.async_dispatch_until_future(future)
        await iterm2.notifications.async_unsubscribe(self.connection, token)
        return future.result

    async def async_get_screen_contents(self):
        """
        :returns: The screen contents, an iterm2.api_pb2.GetBufferResponse

        :throws: :class:`RPCException` if something goes wrong.
        """
        response = await iterm2.rpc.async_get_buffer_with_screen_contents(
            self.connection,
            self.__session_id)
        status = response.get_buffer_response.status
        if status == iterm2.api_pb2.GetBufferResponse.Status.Value("OK"):
            return response.get_buffer_response
        else:
            raise iterm2.rpc.RPCException(iterm2.api_pb2.GetBufferResponse.Status.Name(status))

    async def async_get_buffer_lines(self, trailing_lines):
        """
        Fetches the last lines of the session, reaching into history if needed.

        :param trailing_lines: The number of lines to fetch.

        :returns: The buffer contents, an iterm2.api_pb2.GetBufferResponse

        :throws: :class:`RPCException` if something goes wrong.
        """
        response = await iterm2.rpc.async_get_buffer_lines(
            self.connection,
            trailing_lines,
            self.__session_id)
        status = response.get_buffer_response.status
        if status == iterm2.api_pb2.GetBufferResponse.Status.Value("OK"):
            return response.get_buffer_response
        else:
            raise iterm2.rpc.RPCException(iterm2.api_pb2.GetBufferResponse.Status.Name(status))

    async def async_get_prompt(self):
        """
        Fetches info about the last prompt in this session.

        :returns: iterm2.api_pb2.GetPromptResponse

        :throws: :class:`RPCException` if something goes wrong.
        """
        response = await iterm2.rpc.async_get_prompt(self.connection, self.__session_id)
        status = response.get_prompt_response.status
        if status == iterm2.api_pb2.GetPromptResponse.Status.Value("OK"):
            return response.get_prompt_response
        elif status == iterm2.api_pb2.GetPromptResponse.Status.Value("PROMPT_UNAVAILABLE"):
            return None
        else:
            raise iterm2.rpc.RPCException(iterm2.api_pb2.GetPromptResponse.Status.Name(status))

    async def async_set_profile_property(self, key, json_value):
        """
        Sets the value of a property in this session.

        :param key: The name of the property
        :param json_value: The json-encoded value to set

        :returns: iterm2.api_pb2.SetProfilePropertyResponse

        :throws: :class:`RPCException` if something goes wrong.
        """
        response = await iterm2.rpc.async_set_profile_property(
            self.connection,
            self.session_id,
            key,
            json_value)
        status = response.set_profile_property_response.status
        if status == iterm2.api_pb2.SetProfilePropertyResponse.Status.Value("OK"):
            return response.set_profile_property_response
        else:
            raise iterm2.rpc.RPCException(iterm2.api_pb2.GetPromptResponse.Status.Name(status))

    async def async_get_profile(self):
        """
        Fetches the profile of this session

        :returns: :class:`Profile`.

        :throws: :class:`RPCException` if something goes wrong.
        """
        response = await iterm2.rpc.async_get_profile(self.connection, self.__session_id)
        status = response.get_profile_property_response.status
        if status == iterm2.api_pb2.GetProfilePropertyResponse.Status.Value("OK"):
            return iterm2.profile.Profile(
                self.__session_id,
                self.connection,
                response.get_profile_property_response)
        else:
            raise iterm2.rpc.RPCException(
                iterm2.api_pb2.GetProfilePropertyResponse.Status.Name(status))

    async def async_inject(self, data):
        """
        Injects data as though it were program output.

        :param data: A byte array to inject.
        """
        response = await iterm2.rpc.async_inject(self.connection, data, [self.__session_id])
        status = response.inject_response.status[0]
        if status != iterm2.api_pb2.InjectResponse.Status.Value("OK"):
            raise iterm2.rpc.RPCException(iterm2.api_pb2.InjectResponse.Status.Name(status))

    async def async_activate(self, select_tab=True, order_window_front=True):
        """
        Makes the session the active session in its tab.

        :param select_tab: Whether the tab this session is in should be selected.
        :param order_window_front: Whether the window this session is in should be
          brought to the front and given keyboard focus.
        """
        await iterm2.rpc.async_activate(
            self.connection,
            True,
            select_tab,
            order_window_front,
            session_id=self.__session_id)

    async def async_set_variable(self, name, value):
        """
        Sets a user-defined variable in the session.

        See Badges documentation for more information on user-defined variables.

        :param name: The variable's name.
        :param value: The new value to assign.
        """
        result = await iterm2.rpc.async_variable(
            self.connection,
            self.__session_id,
            [(name, value)],
            [])
        status = result.variable_response.status
        if status != iterm2.api_pb2.VariableResponse.Status.Value("OK"):
            raise iterm2.rpc.RPCException(iterm2.api_pb2.VariableResponse.Status.Name(status))

    async def async_get_variable(self, name):
        """
        Fetches a session variable.

        See Badges documentation for more information on user-defined variables.

        :param name: The variable's name.

        :returns: The variable's value or empty string if it is undefined.
        """
        result = await iterm2.rpc.async_variable(self.connection, self.__session_id, [], [name])
        status = result.variable_response.status
        if status != iterm2.api_pb2.VariableResponse.Status.Value("OK"):
            raise iterm2.rpc.RPCException(iterm2.api_pb2.VariableResponse.Status.Name(status))
        else:
            return result.variable_response.values[0]

    class KeystrokeReader:
        """An asyncio context manager for reading keystrokes.

        Don't create this yourself. Use Session.get_keystroke_reader() instead. See
        its docstring for more info."""
        def __init__(self, connection, session_id):
            self.connection = connection
            self.session_id = session_id
            self.buffer = []
            self.token = None
            self.future = None

        async def __aenter__(self):
            async def async_on_keystroke(_connection, message):
                """Called on keystroke. Saves the keystroke in a buffer."""
                self.buffer.append(message)
                if self.future is not None:
                    temp = self.buffer
                    self.buffer = []
                    self.future.set_result(temp)

            self.token = await iterm2.notifications.async_subscribe_to_keystroke_notification(
                self.connection,
                async_on_keystroke,
                self.session_id)
            return self

        async def get(self):
            """
            Get the next keystroke.

            :returns: An iterm2.api_pb2.KeystrokeNotification.
            """
            self.future = asyncio.Future()
            await self.connection.async_dispatch_until_future(self.future)
            result = self.future.result()
            self.future = None
            return result

        async def __aexit__(self, exc_type, exc, _tb):
            await iterm2.notifications.async_unsubscribe(self.connection, self.token)
            return self.buffer

    class ScreenStreamer:
        """An asyncio context manager for monitoring the screen contents.

        Don't create this yourself. Use Session.get_screen_streamer() instead. See
        its docstring for more info."""
        def __init__(self, connection, session_id, want_contents=True):
            self.connection = connection
            self.session_id = session_id
            self.want_contents = want_contents
            self.future = None
            self.token = None

        async def __aenter__(self):
            async def async_on_update(_connection, message):
                """Called on screen update. Saves the update message."""
                future = self.future
                if future is None:
                    # Ignore reentrant calls
                    return

                self.future = None
                if future is not None and not future.done():
                    future.set_result(message)

            self.token = await iterm2.notifications.async_subscribe_to_screen_update_notification(
                self.connection,
                async_on_update,
                self.session_id)
            return self

        async def __aexit__(self, exc_type, exc, _tb):
            await iterm2.notifications.async_unsubscribe(self.connection, self.token)

        async def get(self):
            """
            Gets the screen contents, waiting until they change if needed.

            :returns: An iterm2.api_pb2.GetBufferResponse.
            """
            future = asyncio.Future()
            self.future = future
            await self.connection.async_dispatch_until_future(self.future)
            self.future = None

            if self.want_contents:
                result = await iterm2.rpc.async_get_buffer_with_screen_contents(
                    self.connection,
                    self.session_id)
                return result

class InvalidSessionId(Exception):
    """The specified session ID is not allowed in this method."""
    pass

class ProxySession(Session):
    """A proxy for a Session.

    This is used when you specify an abstract session ID like "all" or "active".
    Since the session or set of sessions that refers to is ever-changing, this
    proxy stands in for the real thing. It may limit functionality since it
    doesn't make sense to, for example, get the screen contents of "all"
    sessions.
    """
    def __init__(self, connection, session_id):
        super().__init__(connection, session_id)
        self.__session_id = session_id

    def __repr__(self):
        return "<ProxySession %s>" % self.__session_id

    def pretty_str(self, indent=""):
        return indent + "ProxySession %s" % self.__session_id

    async def async_get_screen_contents(self):
        if self.__session_id == "all":
            raise InvalidSessionId()
        return await super(ProxySession, self).async_get_screen_contents()

    async def async_get_buffer_lines(self, trailing_lines):
        if self.__session_id == "all":
            raise InvalidSessionId()
        return await super(ProxySession, self).async_get_buffer_lines(trailing_lines)

    async def async_get_prompt(self):
        if self.__session_id == "all":
            raise InvalidSessionId()
        return await super(ProxySession, self).async_get_prompt()

    async def async_get_profile(self):
        if self.__session_id == "all":
            return iterm2.profile.WriteOnlyProfile(self.__session_id, self.connection)
        return await super(ProxySession, self).async_get_profile()
