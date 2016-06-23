/+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 + Soulcurses - Soul(seek|find) simple chat client                           +
 +                                                                           +
 + Copyright (C) 2005 SeeSchloss <seeschloss@seeschloss.org>                 +
 +                                                                           +
 + This  program  is free software ; you can  redistribute it  and/or modify +
 + it under  the  terms of  the GNU General Public License  as published  by +
 + the  Free  Software  Foundation ;  either  version  2 of  the License, or +
 + (at your option) any later version.                                       +
 +                                                                           +
 + This  program  is  distributed  in the  hope  that  it  will  be  useful, +
 + but   WITHOUT  ANY  WARRANTY ;  without  even  the  implied  warranty  of +
 + MERCHANTABILITY   or   FITNESS   FOR   A   PARTICULAR  PURPOSE.  See  the +
 + GNU General Public License for more details.                              +
 +                                                                           +
 + You  should  have  received  a  copy  of  the  GNU General Public License +
 + along   with  this  program ;  if  not,  write   to   the  Free  Software +
 + Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA +
 +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++/

module soulcurses;

import system, messages, message_codes;

import std.cstream, std.file,  std.datetime;
import std.socket, std.stream, std.socketstream, core.thread;

import std.json, std.array, std.string, std.variant, std.regex;
import std.random, core.stdc.stdlib;

Server server;

string[] rooms;
string[string] admins;
string[string] ignore;
string[][string] reactions;
string conf_file = "";
string current_room = "";

extern (C)
	{
	void signal(int sig, void *func);
	void sighup_handler(int sig)
		{
		parse_conf(conf_file);
		}
	}


class InputThread : core.thread.Thread
	{
	private Server server;

	this (Server server)
		{
		this.server = server;
		super (&run);
		}

	private void run ()
		{
		while (!din.eof())
			{
			string line = din.readLine().idup;
			this.server.say (line);
			}
		}
	}

void log (S...)(S args)
	{
	auto time = Clock.currTime(UTC());
	dout.writef("[%04d/%02d/%02d %02d:%02d:%02d UTC] ", time.year, time.month, time.day, time.hour, time.minute, time.second);
	dout.writef(args);
	dout.writef("\n");
	}

void err (S...)(S args)
	{
	auto time = Clock.currTime(UTC());
	derr.writef("[%04d/%02d/%02d %02d:%02d:%02d UTC] ", time.year, time.month, time.day, time.hour, time.minute, time.second);
	derr.writef(args);
	derr.writef("\n");
	}

int main (string[] args)
	{
	signal(1, &sighup_handler);

	if (args.length == 2)
		{
		conf_file = args[1];
		parse_conf (conf_file);
		}
	else if (args.length == 1)
		{
		conf_file = system.getenv ("HOME") ~ "/" ~ ".soulcursesrc";
		parse_conf (conf_file);
		}
	else
		{
		usage (args);
		return 1;
		}

	InputThread thread = new InputThread(server);
	thread.start();

	setup_server (false);

	return 0;
	}

void setup_server (bool new_thread)
	{
	server.on_reception (Login         , &on_login);
	server.on_reception (SayChatroom   , &on_saychatroom);
	server.on_reception (UserJoinedRoom, &on_join);
	server.on_reception (UserLeftRoom  , &on_part);
	server.on_reception (MessageUser   , &on_pm);
//	server.on_reception (RoomTicker    , &on_ticker);

	while (true)
		{
		try
			{
			if (!server.connected) server.connect ();
			server.listen ();
			}
		catch (ReadException e)
			{
			}
		catch (InvalidMessageException e)
			{
			if (e.message.size () > 4)
				{
				int n;
				e.message.read (n);
				if (n < message_name.length)
					err ("Bad message received (%s), code %d (%s)", e.toString (), n, message_name[n]);
				else
					err ("Bad message received (%s), code %d", e.toString (), n);
				}
			else
				{
				err ("Bad message received (%s)", e.toString ());
				}
			server.disconnect ();
			}
		catch (ServerException e)
			{
			err ("%s", e.toString ());
			}

		//Thread.sleep (15_000_000);
		}
	}

void on_login (Stream s, int code)
	{
	SLogin m = new SLogin (s);

	if (m.success)
		{
		log ("Logged in, MOTD :\n%s", m.mesg);
		}

	server.send(new USharedFoldersFiles (1337, int.max));

	foreach (string room ; rooms)
		{
		server.send (new UJoinRoom (room));
		log ("Asking to join room %s", room);
		}
	}

void on_saychatroom (Stream s, int code)
	{
	auto time = Clock.currTime(UTC());
	SSayChatroom m = new SSayChatroom (s);
	if (m.user !in ignore)
		{
		printf ("[%04d/%02d/%02d %02d:%02d:%02d UTC] ", time.year, time.month, time.day, time.hour, time.minute, time.second);
		//printf ("[%.*s] %.*s> %.*s\n", m.room, m.user, m.mesg);
		printf ("[%s] %s> %s\n", toStringz(m.room), toStringz(m.user), toStringz(m.mesg));
		//printf ("[%.*s] %.*s> ", m.room, m.user);
		//dout.writefln ("%s", m.mesg);
		}
	}

void on_join (Stream s, int code)
	{
	SUserJoinedRoom m = new SUserJoinedRoom (s);
	//log ("Someone joined room %s: %s", m.room, m.username);
	}

void on_part (Stream s, int code)
	{
	SUserLeftRoom m =new SUserLeftRoom (s);
	//log ("Someone left room %s: %s", m.room, m.username);
	}

void on_ticker (Stream s, int code)
	{
	SRoomTicker m = new SRoomTicker (s);

	auto time = Clock.currTime(UTC());
	printf("[%04d/%02d/%02d %02d:%02d:%02d UTC] Tickers in room %s:\n", time.year, time.month, time.day, time.hour, time.minute, time.second, m.room.toStringz());
	foreach (string user, string ticker; m.tickers)
		{
		printf("[%04d/%02d/%02d %02d:%02d:%02d UTC] %s: %s\n", time.year, time.month, time.day, time.hour, time.minute, time.second, user.toStringz(), ticker.toStringz());
		}
	}

void on_pm (Stream s, int code)
	{
	SMessageUser m = new SMessageUser (s);
	if (m.from in ignore)
		{
		server.send (new UMessageAcked (m.id));
		return;
		}

	auto time = Clock.currTime(UTC());
	printf("[%04d/%02d/%02d %02d:%02d:%02d UTC] Received PM from %s: ", time.year, time.month, time.day, time.hour, time.minute, time.second, m.from.toStringz());
	printf("\"%s\"\n", m.content.toStringz());
	
	void answer (S...)(S args)
		{
		server.send (new UMessageUser (m.from, format(args)));
		}

	if (m.from in admins)
		{
		string[] commands = split (m.content);

		switch (commands[0])
			{
			case "join":
				if (commands.length > 1)
					{
					string room = std.array.join (commands[1..$], " ");
					answer ("Okay, joining room %s", room);
					server.send (new UJoinRoom (room));
					}
				break;
			case "part":
				if (commands.length > 1)
					{
					string room = std.array.join (commands[1..$], " ");
					answer ("Okay, leaving room %s", room);
					server.send (new ULeaveRoom (room));
					}
				break;
			case "say":
				if (commands.length > 2)
					{
					string room = commands[1];
					string mesg = std.array.join (commands[2..$], " ");
					answer ("Okay, speaking in room %s", room);
					server.send (new USayChatroom (room, mesg));
					}
				break;
			case "reload":
				answer ("Reloading configuration");
				parse_conf(conf_file);
				answer ("Admins: %s", admins.keys);
				break;
			case "help":
				answer("Available commands: join, part, say, reload, help");
				break;
			default:
				answer ("I didn't understand anything");
			}
		}
	else
		{
		//answer ("Mom told me not to talk to strangers.");
		}

	server.send (new UMessageAcked (m.id));
	}

void answer (string room, string mesg)
	{
	if (mesg.length)
		{
		server.send (new USayChatroom (room, mesg));
		}
	}

void usage (string[] args)
	{
	err ("Usage: %s [configuration file]", args[0]);
	}

alias VariantN!(maxSize!(string, JSONValue[string], long, JSONValue[]), string, JSONValue[string], long, JSONValue[]) JSONVariant;

JSONVariant getJSONValue(JSONValue value)
	{
	switch (value.type)
		{
		case JSON_TYPE.OBJECT:
			return JSONVariant(value.object);
		case JSON_TYPE.STRING:
			return JSONVariant(value.str);
		case JSON_TYPE.INTEGER:
			return JSONVariant(value.integer);
		case JSON_TYPE.ARRAY:
			return JSONVariant(value.array);
		default:
			throw new Exception("Unknown value type.");
		}
	}

T getJSON (T)(JSONValue value)
	{
	T val;
	try
		{
		val = getJSONValue(value).get!(T);
		}
	catch (VariantException e)
		{
		err ("Bad value type (%s, should be %s) for configuration key", getJSONValue(value).type, T.stringof);
		}
	return val;
	}

void parse_conf (string file)
	{
	string[] missing;
	
	JSONValue conf = parseJSON (readText(file));

	string serv = "server.slsknet.org";
	ushort port = 2242;
	string username, password;
	int clientversion = 198;

	if (conf.type == JSON_TYPE.OBJECT)
		{
		debug log ("Parsing configuration...");
		foreach (string key, JSONValue value; conf.object)
			{
			switch (key)
				{
				case "server":
					serv = getJSON!(string)(value);
					debug log ("server: %s", serv);
					break;
				case "port":
					port = cast(ushort)getJSON!(long)(value);
					debug log ("port: %s", port);
					break;
				case "username":
					username = getJSON!(string)(value);
					debug log ("username: %s", username);
					break;
				case "password":
					password = getJSON!(string)(value);
					debug log ("password: ********");
					break;
				case "version":
					clientversion = getJSON!(int)(value);
					debug log ("client version: %s", clientversion);
					break;
				case "rooms":
					rooms = [];
					foreach (JSONValue room; getJSON!(JSONValue[])(value))
						{
						rooms ~= getJSON!(string)(room);
						current_room = getJSON!(string)(room);
						}
					debug log ("rooms: %s", rooms);
					break;
				case "admins":
					admins = admins.init;
					foreach (JSONValue admin; getJSON!(JSONValue[])(value))
						{
						string str = getJSON!(string)(admin);
						admins[str] = str;
						}
					debug log ("admins: %s", admins);
					break;
				case "ignore":
					ignore = ignore.init;
					foreach (JSONValue ignored; getJSON!(JSONValue[])(value))
						{
						string str = getJSON!(string)(ignored);
						ignore[str] = str;
						}
					debug log ("ignore: %s", ignore);
					break;
				case "reactions":
					reactions = reactions.init;
					foreach (string trigger, JSONValue reactionlist; getJSON!(JSONValue[string])(value))
						{
						trigger = format ("^%s$", trigger);
						reactions[trigger] = [];
						foreach (JSONValue reaction; getJSON!(JSONValue[])(reactionlist))
							{
							reactions[trigger] ~= getJSON!(string)(reaction);
							}
						}
					debug log ("reactions: %s", reactions);
					break;
				default:
					err ("Unknown configuration key: %s", key);
				}
			}
		}

	if (!username)
		{
		username = "None";
		password = "None";
		err ("No username given in configuration, logging as %s/%s.", username, password);
		}

	if (!server) server = new Server (serv, port, username, password, clientversion);
	server.current_room = current_room;
	}

class Server
	{
	string server;
	ushort port;

	int    clientversion;

	string username;
	string password;

	Socket socket;
	Stream stream;

	string current_room;

	void function (Stream, int)[int] actions;

	this (string server, ushort port, string username, string password, int clientversion = 198)
		{
		this.server         = server;
		this.port           = port;
		this.username       = username;
		this.password       = password;
		this.clientversion  = clientversion;
		this.current_room   = "";
		}

	bool connected ()
		{
		return (socket && socket.isAlive && stream && !stream.eof ());
		}

	void send (Message message)
		{
		if (!stream.eof ())
			{
			ubyte[] bytes = message.toBytes ();
			stream.write (cast (int) bytes.length);
			auto written = stream.write (bytes);
			stream.flush ();

			if (written != bytes.length)
				{
				throw new WriteException (format ("Only %d bytes out of %d could be written", written, bytes.length));
				}
			}
		else
			{
			throw new ServerException ("Not connected to server");
			}
		}

	void on_reception (int code, void function (Stream, int) action)
		{
		this.actions[code] = action;
		}

	void listen ()
		{
		while (true) receive ();
		}

	void connect ()
		{
		try
			{
			socket = new TcpSocket (new InternetAddress (this.server, this.port));
			}
		catch (SocketException e)
			{
			throw new ServerException (e.toString ());
			}

		//stream = new BufferedStream (new SocketStream (socket), 16384);
		stream = new SocketStream (socket);

		send (new ULogin (username, password, clientversion, clientversion != 198 && clientversion != 150));
		}

	void disconnect ()
		{
		log ("Disconnecting.");
		socket.shutdown (SocketShutdown.BOTH);
		socket.close ();
		}

	void receive ()
		{
		if (!stream.eof ())
			{
			int length;
			stream.read (length);

			if (length < 4 || length > 1024*1024)
				{ // messages are accepted if they are less than 1 MB
				int code = 0;
				string s = "";
				if (length >= 4)
					{
					stream.read (code);
					if (code < message_name.length)
						s = message_name[code];
					}

				if (length < 4) throw new InvalidMessageException (format ("Message length invalid (%d)", length));
				}
			
			ubyte[] bytes; bytes.length = length;

			int read;

			//int read = stream.read (bytes);
			debug log ("Reading the code... ");
			int code; stream.read (code);
			debug log ("code is %d", code);

			if (code < message_name.length)
				debug log ("message type is %s", message_name[code]);

			length -= code.sizeof;

			debug log ("Reading the %d bytes of the message...", length);
			for (int i = 0 ; i < length ; i++)
				{
				stream.read (bytes[i]);
				read++;
				}
			debug log ("successfuly read.");

			if (read != length)
				throw new InvalidMessageException (
					format ("Could only read %d bytes on the %d expected",
						read,
						length));
			process_message (new MemoryStream (bytes), code);
			}
		else
			{
			throw new ServerException ("Not connected to server");
			}
		}

	void say (string line)
		{
		if (this.current_room != "")
			{
			string[] commands = split (line);
			if (commands.length > 2)
				{
				switch (commands[0])
					{
					case "/pm":
						this.send (new UMessageUser (commands[1], commands[2..$].join(" ")));
						break;
					case "/say":
						string room = commands[1];
						string mesg = commands[2..$].join(" ");
						this.send (new USayChatroom (room, mesg));
						break;
					default:
						this.send (new USayChatroom (this.current_room, line));
						break;
					}
				}
			else if (commands.length > 1)
				{
				switch (commands[0])
					{
					case "/join":
						string room = commands[1..$].join(" ");
						this.send (new UJoinRoom (room));
						break;
					case "/part":
						string room = commands[1..$].join(" ");
						this.send (new ULeaveRoom (room));
						break;
					default:
						this.send (new USayChatroom (this.current_room, line));
						break;
					}
				}
			else
				{
				switch (commands[0])
					{
					case "/reload":
						log ("Reloading configuration");
						parse_conf(conf_file);
						log ("Admins: %s", admins.keys);
						break;
					case "/help":
						log ("Available commands: join, part, say, reload, help");
						break;
					default:
						this.send (new USayChatroom (this.current_room, line));
					}
				}
			}
		}

	void process_message (Stream s, int code = -1)
		{
		if (code < 0) s.read (code);

		if (code == Login)
			{
			SLogin m = new SLogin (s);

			if (m.success)
				{
				SLogin fake_message = new SLogin (m.success, m.mesg, m.addr);
				s = new MemoryStream (fake_message.toBytes());
				s.read (code);
				}
			else
				{
				log ("Could not log in, reason :\n%s", m.mesg);
				throw new ServerException ("Could not log in : " ~ m.mesg);
				}

			this.send (new USetWaitPort (1789));
			log ("Wait port set to %d", 1789);
			}

		if (code in actions) actions[code] (s, code);
		else if (0 in actions) actions[0] (s, code);
		}
	}

class ServerException : Exception
	{
	this (string m) { super (m); }
	}

class InvalidMessageException : Exception
	{
	this (string m, ubyte[] bytes = null)
		{
		super (m);
		if (bytes)
			this.message = new MemoryStream (bytes);
		else
			this.message = new MemoryStream ();
		}

	MemoryStream message;
	}
