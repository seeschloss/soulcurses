/+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 + SoulFind - Free SoulSeek server                                           +
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


module messages;

import defines;

import undead.stream, std.outbuffer, undead.cstream;
import std.format, std.digest.md, std.conv, std.string;

private import message_codes;

class Message
	{	// Server message
	int code;
	OutBuffer b;

	ubyte[] toBytes () {return b.toBytes ();}

	this (int code)
		{
		b = new OutBuffer ();
		this.code = code;
		writei (code);
		}

	void writei (int i)
		{
		try {b.write (i);}
		catch (WriteException e) {derr.writefln (e, " when trying to send an int : ", i);}
		}

	void writei (ulong l)
		{
		int i = cast (int) l;
		try {b.write (i);}
		catch (WriteException e) {derr.writefln (e, " when trying to send an int : ", i);}
		}
		
	void writeb (byte o)
		{
		try {b.write (o);}
		catch (WriteException e) {derr.writefln (e, " when trying to send a byte : ", o);}
		}
	
	void writes (string s)
		{
		try
			{
			b.write (cast (int) s.length);
			b.write (s);
			}
		catch (WriteException e) {derr.writefln (e, " when trying to send a string : ", s, "(", s.length, ")");}
		}

	int length;
	Stream s;

	this (Stream s)
		{
		this.s = s;
		}

	int readi ()
		{ // read an int
		int i;
		try {s.read (i);}
		catch (ReadException e)
			{
			derr.writefln ("message code ", code, ", length ", length, " trying to read an int : ", e);
			i = 0;
			}
		return i;
		}
	
	byte readb ()
		{ // read a byte
		byte b;
		try {s.read (b);}
		catch (ReadException e)
			{
			derr.writefln ("message code ", code, ", length ", length, " trying to read a byte : ", e);
			b = 0;
			}
		return b;
		}
	
	string reads ()
		{ // read a string
		int    slen;
		string str;
		try
			{
			slen = readi ();
			str = to!string(s.readString (slen));
			}
		catch (ReadException e)
			{
			derr.writefln ("message code ", code, ", length ", length, " trying to read a string : ", e);
			str = "";
			}
		return str;
		}
	}

class ULogin : Message
	{		// New login
	string name;	// user name
	string pass;	// user password
	int    vers;	// client version (198 for nicotine and museek, 180 for pyslsk)

	this (Stream s)
		{
		super (s);

		name = reads ();
		pass = reads ();
		vers = readi ();
		}

	this (string name, string pass, int vers, bool md5 = false)
		{
		super (Login);

		writes (name);
		writes (pass);
		writei (vers);

		if (md5)
			{	// the official  server now needs this md5sum
				// to be sent by the client at login when the
				// cient version is not 198 or 150.
			ubyte[16] digest;
			digest = md5Of (name ~ pass);
			string sum;
			foreach (ubyte u ; digest)
				sum ~= format ("%02x", u);
			writes (sum);
			}
		}
	}

class USetWaitPort : Message
	{		// A client is telling us which port it is listening on
	int port;	// port number
	this (Stream s)
		{
		super (s);

		port = readi ();
		}
	
	this (int port)
		{
		super (SetWaitPort);

		writei (port);
		}
	}
	
class UGetPeerAddress : Message
	{		// A client is asking for someone's address
	string user;	// name of the user to get the address of
	
	this (Stream s)
		{
		super (s);

		user = reads ();
		}
	
	this (string user)
		{
		super (GetPeerAddress);

		writes (user);
		}
	}

class UUserExists : Message
	{		// A client wants to know if some user exists ?
	string user;	// name of the user

	this (Stream s)
		{
		super (s);

		user = reads ();
		}
	
	this (string user)
		{
		super (UserExists);

		writes (user);
		}
	}

class UAddUser : Message
	{		// A client wants to watch someone else
	string user;	// name of the user to watch

	this (Stream s)
		{
		super (s);

		user = reads ();
		}
	
	this (string user)
		{
		super (AddUser);

		writes (user);
		}
	}

class UGetUserStatus : Message
	{		// A client wants to know the status of someone
	string user;	// name of the user
	
	this (Stream s)
		{
		super (s);

		user = reads ();
		}
	
	this (string user)
		{
		super (GetUserStatus);

		writes (user);
		}
	}

class USayChatroom : Message
	{		// A client wants to say something in a chatroom
	string room;	// room to talk in
	string str;	// what to say
	
	this (Stream s)
		{
		super (s);
		
		room   = reads ();
		str    = reads ();
		}
	
	this (string room, string str)
		{
		super (SayChatroom);

		writes (room);
		writes (str);
		}
	}

class UJoinRoom : Message
	{		// Client wants to join a room
	string room;	// room the client wants to join

	this (Stream s)
		{
		super (s);

		room = reads ();
		}
	
	this (string room)
		{
		super (JoinRoom);

		writes (room);
		}
	}

class ULeaveRoom : Message
	{		// Client wants to leave a room
	string room;	// room the client wants to leave

	this (Stream s)
		{
		super (s);

		room = reads ();
		}
	
	this (string room)
		{
		super (LeaveRoom);

		writes (room);
		}
	}

class UConnectToPeer : Message
	{		// Client cannot connect to another one and wants us to ask the other to connect to him
	int token;	// connection token
	string user;	// user name
	string type;	// connection type ("F" if for a file transfers, "P" otherwise)

	this (Stream s)
		{
		super (s);

		token = readi ();
		user  = reads ();
		type  = reads ();
		}
	
	this (int token, string user, string type)
		{
		super (ConnectToPeer);

		writei (token);
		writes (user);
		writes (type);
		}
	}

class UMessageUser : Message
	{		// Client wants to send a private message
	string user;	// user to send the message to
	string message; // message content

	this (Stream s)
		{
		super (s);

		user    = reads ();
		message = reads ();
		}
	
	this (string user, string message)
		{
		super (MessageUser);

		writes (user);
		writes (message);
		}
	}

class UMessageAcked : Message
	{		// Client acknowledges a private message
	int id;		// message id
	
	this (Stream s)
		{
		super (s);

		id = readi ();
		}
	
	this (int id)
		{
		super (MessageAcked);

		writei (id);
		}
	}

class UFileSearch : Message
	{		// Client makes a filesearch
	int token;	// search token
	string strng;	// search string

	this (Stream s)
		{
		super (s);

		token = readi ();
		strng = reads ();
		}
	
	this (int token, string string)
		{
		super (FileSearch);

		writei (token);
		writes (string);
		}
	}

class USetStatus : Message
	{		// Client sets its status
	int status;	// -1 : Unknown - 0 : Offline - 1 : Away - 2 : Online

	this (Stream s)
		{
		super (s);

		status = readi ();
		}
	
	this (int status)
		{
		super (SetStatus);

		writei (status);
		}
	}

class USendSpeed : Message
	{		// Client reports a transfer speed
	string user;	// user name
	int    speed;   // speed
	
	this (Stream s)
		{
		super (s);

		user  = reads ();
		speed = readi ();
		}
	
	this (string user, int speed)
		{
		super (SendSpeed);

		writes (user);
		writei (speed);
		}
	}

class USharedFoldersFiles : Message
	{		// Client tells us how many files and folder it is sharing
	int nb_folders;	// number of folders
	int nb_files;	// number of files

	this (Stream s)
		{
		super (s);

		nb_folders = readi ();
		nb_files   = readi ();
		}
	
	this (int nb_folders, int nb_files)
		{
		super (SharedFoldersFiles);

		writei (nb_folders);
		writei (nb_files);
		}
	}

class UGetUserStats : Message
	{		// Client wants the stats of someone
	string user;	// user name

	this (Stream s)
		{
		super (s);

		user = reads ();
		}
	
	this (string user)
		{
		super (GetUserStats);

		writes (user);
		}
	}

class UAddThingILike : Message
	{		// Client likes thing
	string thing;	// thing (s)he likes

	this (Stream s)
		{
		super (s);

		thing = reads ();
		}
	
	this (string thing)
		{
		super (AddThingILike);

		writes (thing);
		}
	}

class URemoveThingILike : Message
	{		// Client doesn't like thing anymore
	string thing;	// the thing

	this (Stream s)
		{
		super (s);

		thing = reads ();
		}
	
	this (string thing)
		{
		super (RemoveThingILike);

		writes (thing);
		}
	}

class UAddThingIHate : Message
	{		// Client hates thing
	string thing;	// thing (s)he likes

	this (Stream s)
		{
		super (s);

		thing = reads ();
		}
	
	this (string thing)
		{
		super (AddThingIHate);

		writes (thing);
		}
	}

class URemoveThingIHate : Message
	{		// Client doesn't hate thing anymore
	string thing;	// the thing

	this (Stream s)
		{
		super (s);

		thing = reads ();
		}
	
	this (string thing)
		{
		super (RemoveThingIHate);

		writes (thing);
		}
	}

class UAddToPrivileged : Message
	{		// An admin gives privileges to an user
	string user;	// user to give the privileges to
	int    time;	// privileges credits

	this (Stream s)
		{
		super (s);

		user = reads ();
		time = readi ();
		}
	
	this (string user, int time)
		{
		super (AddToPrivileged);

		writes (user);
		writei (time);
		}
	}

class UGetItemRecommendations : Message
	{		// An user wants to get recommendations
			// for a particular item
	string item;

	this (Stream s)
		{
		super (s);

		item = reads ();
		}
	
	this (string item)
		{
		super (ItemRecommendations);

		writes (item);
		}
	}

class UItemSimilarUsers : Message
	{		// An user wants to know who
			// likes a particular item
	string item;

	this (Stream s)
		{
		super (s);

		item = reads ();
		}
	
	this (string item)
		{
		super (ItemSimilarUsers);

		writes (item);
		}
	}

class USetRoomTicker : Message
	{		// Client sets a new ticker for a room
	string room;	// room name
	string tick;	// ticker content

	this (Stream s)
		{
		super (s);

		room = reads ();
		tick = reads ();
		}
	
	this (string room, string tick)
		{
		super (SetRoomTicker);

		writes (room);
		writes (tick);
		}
	}

class UUserPrivileges : Message
        {               // Client wants to know if someone has privileges
        string user;    // user name

        this (Stream s)
                {
                super (s);
        
                user = reads ();
                }
	
	this (string user)
		{
		super (UserPrivileges);

		writes (user);
		}
        }

class UAdminMessage : Message
	{		// An admin sends a message
	string mesg;	// the message

	this (Stream s)
		{
		super (s);

		mesg = reads ();
		}
	
	this (string mesg)
		{
		super (AdminMessage);

		writes (mesg);
		}
	}

class UGivePrivileges : Message
	{		// Client wants to give privileges to somebody else
	string user;	// user to give the privileges to
	int    time;	// time to give

	this (Stream s)
		{
		super (s);

		user = reads ();
		time = readi ();
		}
	
	this (string user, int time)
		{
		super (GivePrivileges);

		writes (user);
		writei (time);
		}
	}

class UCantConnectToPeer : Message
	{		// Client tells us he couldn't connect to someone
	int token;	// message token
	string user;	// user who requested the connection

	this (Stream s)
		{
		super (s);

		token = readi ();
		user  = reads ();
		}
	
	this (int token, string user)
		{
		super (CantConnectToPeer);

		writei (token);
		writes (user);
		}
	}

class SLogin : Message
	{	// If the login succeeded, send the MOTD and the external IP of the client
		// if not, send the error message
	this (byte success, string mesg, int addr = 0, string password = null)
		{
		super (Login);
		
		writeb (success);	// success (0 = fail / 1 = success)
		writes (mesg);		// server message
		if (success)
			{
			writei (addr);	// external IP address of the client

			if (!(password is null))
				{	// the official  server now sends this md5sum
					// back to the client at login.  The official
					// client uses it to check if it is connected
					// to the official server.
				ubyte[16] digest;
				md5Of (digest, password);
				string sum;
				foreach (ubyte u ; digest)
					sum ~= format ("%02x", u);
				writes (sum);
				}
			}
		}
		
	byte   success;
	string mesg;
	int    addr;
	
	this (Stream s)
		{
		super (s);

		success = readb ();
		mesg    = reads ();
		if (success) addr = readi ();
		}
	}

class SGetPeerAddress : Message
	{	// Send the address and port of user user
	this (string username, int address, int port)
		{
		super (GetPeerAddress);
		
		writes (username);	// username the address belongs to
		writei (address);	// IP address
		writei (port);		// port number
		}
	
	string username;
	int    address;
	int    port;

	this (Stream s)
		{
		super (s);

		username = reads ();
		address  = readi ();
		port     = readi ();
		}
	}

class SUserExists : Message
	{	// A client asked whether user user exists or not
	this (string user, byte exists)
		{
		super (UserExists);

		writes (user);   // username
		writeb (exists); // whether the user exists or not
		}
	
	string user;
	byte   exists;

	this (Stream s)
		{
		super (s);

		user   = reads ();
		exists = readb ();
		}
	}

class SAddUser : Message
	{	// A client asked to watch user, tell him if this user exists or not
		// the official server doesn't seem to be sending that anymore
	this (string user, byte exists)
		{
		super (AddUser);

		writes (user);   // username
		writeb (exists); // whether the user exists or not
		}
	
	string user;
	byte   exists;

	this (Stream s)
		{
		super (s);

		user   = reads ();
		exists = readb ();
		}
	}

class SGetUserStatus : Message
	{	// Send the status of user user
	this (string username, int status)
		{
		super (GetUserStatus);

		writes (username);	// username
		writei (status);	// user status (see the class User)
		}

	string username;
	int    status;

	this (Stream s)
		{
		super (s);

		username = reads ();
		status   = readi ();
		}
	}

class SSayChatroom : Message
	{	// User user has said mesg in room room
	this (string room, string user, string mesg)
		{
		super (SayChatroom);

		writes (room); // room the message comes from
		writes (user); // the user who said it
		writes (mesg); // what (s)he said
		}
	
	string room;
	string user;
	string mesg;

	this (Stream s)
		{
		super (s);

		room = reads ();
		user = reads ();
		mesg = reads ();
		}
	}

class SRoomList : Message
	{	// Send the list of rooms
	this (int[string] rooms)
		{
		super (RoomList);
		
		writei (rooms.length);	// number of room names we will send
		foreach (string room ; rooms.keys)
			{	// list of all the rooms
			writes (room);
			}
		
		writei (rooms.length);	// number of user counts
		foreach (int users ; rooms.values)
			{	// list of all the user counts, in the same order
			writei (users);
			}
		}
	
	int[string] rooms;

	this (Stream s)
		{
		super (s);

		int n = readi ();
		
		string[] room_names;
		
		room_names.length = n;
		
		for (int i = 0 ; i < n ; i++)
			{
			room_names[i] = reads ();
			}

		n = readi ();

		for (int i = 0 ; i < n ; i++)
			{
			rooms[room_names[i]] = readi ();
			}
		}
	}

class SJoinRoom : Message
	{	// Give info on the room to a client who just joined it
	this (string room, string[] usernames, int[string] statuses, int[string] speeds, int[string] download_numbers, int[string] somethings, int[string] shared_files, int[string] shared_folders, int[string] slots_full)
		{
		super (JoinRoom);

		writes (room);	// the room the user just joined
		auto n = usernames.length;

		writei (n);	// number of user names we will send
		foreach (string username ; usernames)
			{	// list of all the user names
			writes (username);
			}
		
		writei (n);	// number of user statuses we will send
		foreach (string username ; usernames)
			{	// list of all the user statuses
			writei (statuses        [username]);
			}
		
		writei (n);	// number of stats we will send
		foreach (string username ; usernames)
			{
			writei (speeds          [username]);	// speed of each user
			writei (download_numbers[username]);	// number of files downloaded ever
			writei (somethings      [username]);	// something ? 1789 is a good number
			writei (shared_files    [username]);	// nb of shared files
			writei (shared_folders  [username]);	// nb of shared folders
			}
		
		writei (n);	// number of slots records we will send...
		foreach (string username ; usernames)
			{	// list of nb of full slots for each user
			writei (slots_full      [username]);
			}
		}
	
	string room;
	string[]    usernames;
	int[string] statuses;
	int[string] speeds;
	int[string] download_numbers;
	int[string] somethings;
	int[string] shared_files;
	int[string] shared_folders;
	int[string] slots_full;
	
	this (Stream s)
		{
		super (s);

		room = reads ();

		int n = readi ();
		usernames.length = n;

		for (int i = 0 ; i < n ; i++)
			{
			usernames[i] = reads ();
			}

		n = readi ();

		for (int i = 0 ; i < n ; i++)
			{
			statuses        [usernames[i]] = readi ();
			}

		n = readi ();

		for (int i = 0 ; i < n ; i++)
			{
			speeds          [usernames[i]] = readi ();
			download_numbers[usernames[i]] = readi ();
			somethings      [usernames[i]] = readi ();
			shared_files    [usernames[i]] = readi ();
			shared_folders  [usernames[i]] = readi ();
			}

		n = readi ();

		for (int i = 0 ; i < n ; i++)
			{
			slots_full      [usernames[i]] = readi ();
			}
		}
	}
	
class SLeaveRoom : Message
	{	// Tell a client he has to leave a room
	this (string room)
		{
		super (LeaveRoom);

		writes (room);	// the room the user left
		}
	
	string room;

	this (Stream s)
		{
		super (s);

		room = reads ();
		}
	}

class SUserJoinedRoom : Message
	{	// User user has joined the room room
	this (string room, string username, int status, int speed, int download_number, int something, int shared_files, int shared_folders, int slots_full)
		{
		super (UserJoinedRoom);

		writes (room);			// the room an user joined
		writes (username);		// name of the user who joined
		writei (status);		// status
		writei (speed);			// speed
		writei (download_number);	// download number ?
		writei (something);		// something ?
		writei (shared_files);		// shared files
		writei (shared_folders);	// shared folders
		writei (slots_full);		// slots full
		}
	
	string room;
	string username;
	int    status;
	int    speed;
	int    download_number;
	int    something;
	int    shared_files;
	int    shared_folders;
	int    slots_full;

	this (Stream s)
		{
		super (s);

		room		= reads ();
		username        = reads ();
		status          = readi ();
		speed           = readi ();
		download_number = readi ();
		something       = readi ();
		shared_files    = readi ();
		shared_folders  = readi ();
		slots_full      = readi ();
		}
	}

class SUserLeftRoom : Message
	{	// User user has left the room room
	this (string username, string room)
		{
		super (UserLeftRoom);

		writes (room);		// the room an user left
		writes (username);	// name of the user who left
		}

	string room;
	string username;

	this (Stream s)
		{
		super (s);

		room     = reads ();
		username = reads ();
		}
	}

class SConnectToPeer : Message
	{	// Ask a peer to connect back to user
	this (string username, string type, int address, int port, int token)
		{
		super (ConnectToPeer);

		writes (username);	// username of the peer to connect to
		writes (type);		// type of the connection ("F" if it's for a filetransfer, "P" otherwise)
		writei (address);	// IP address of the peer to connect to
		writei (port);		// port to use
		writei (token);		// message token
		}
	
	string username;
	string type;
	int    address;
	int    port;
	int    token;

	this (Stream s)
		{
		super (s);

		username = reads ();
		type     = reads ();
		address  = readi ();
		port     = readi ();
		token    = readi ();
		}
	}

class SMessageUser : Message
	{	// Send the PM
	this (int id, int timestamp, string from, string content)
		{
		super (MessageUser);

		writei (id);		// message id
		writei (timestamp);	// timestamp (seconds since 1970)
		writes (from);		// sender
		writes (content);	// message content
		}
	
	int    id;
	int    timestamp;
	string from;
	string content;

	this (Stream s)
		{
		super (s);

		id        = readi ();
		timestamp = readi ();
		from      = reads ();
		content   = reads ();
		}
	}

class SFileSearch : Message
	{	// Send a filesearch
	this (string username, int token, string str)
		{
		super (FileSearch);

		writes (username);	// username of the one who is doing the search
		writei (token);		// search token
		writes (str);	// search string
		}
	
	string username;
	int    token;
	string str;

	this (Stream s)
		{
		super (s);

		username = reads ();
		token    = readi ();
		str      = reads ();
		}
	}

class SServerPing : Message
	{	// Pong, in response to a client ping
	this ()
		{
		super (ServerPing);
		}
	}

class SGetUserStats : Message
	{	// Send the stats of user user
	this (string username, int speed, int download_number, int something, int shared_files, int shared_folders)
		{
		super (GetUserStats);

		writes (username);		// user name
		writei (speed);			// speed (in B/s)
		writei (download_number);	// download number ?
		writei (something);		// something ?
		writei (shared_files);		// shared files
		writei (shared_folders);	// shared folders
		}
	
	string username;
	int    speed;
	int    download_number;
	int    something;
	int    shared_files;
	int    shared_folders;

	this (Stream s)
		{
		super (s);

		username        = reads ();
		speed           = readi ();
		download_number = readi ();
		something       = readi ();
		shared_files    = readi ();
		shared_folders  = readi ();
		}
	}

class SGetRecommendations : Message
	{	// Send the list of recommendations for this client
	this (int[string] list)	// list[artist] = level
		{
		super (GetRecommendations);

		writei (list.length);	// if you can't guess, stop reading now !
		foreach (string artist, int level ; list)
			{
			writes (artist);	// artist name
			writei (level);		// « level » of recommendation
			}
		}
	
	int[string] list;

	this (Stream s)
		{
		super (s);

		int n = readi ();
		for (int i = 0 ; i < n ; i++)
			{
			string artist = reads ();
			int    level  = readi ();

			list[artist] = level;
			}
		}
	}

class SGetGlobalRecommendations : Message
	{	// Send the list of global recommendations
		// the code is exactly the same as for GetRecommendations.
	this (int[string] list)
		{
		super (GlobalRecommendations);

		writei (list.length);	// if you can't guess, you should have stopped several lines ago...
		foreach (string artist, int level ; list)
			{
			writes (artist);	// artist name
			writei (level);		// « level » of recommendation
			}
		}
	
	int[string] list;

	this (Stream s)
		{
		super (s);

		int n = readi ();
		for (int i = 0 ; i < n ; i++)
			{
			string artist = reads ();
			int    level  = readi ();

			list[artist] = level;
			}
		}
	}

class SRelogged : Message
	{	// Tell a client he has just logged from elsewhere before disconnecting it
	this ()
		{
		super (Relogged);
		}
	}

class SRoomAdded : Message
	{	// A room has been created
	this (string room)
		{
		super (RoomAdded);

		writes (room);	// name of the room
		}

	string name;

	this (Stream s)
		{
		super (s);

		name = reads ();
		}
	}

class SRoomRemoved : Message
	{	// A room has been removed
	this (string room)
		{
		super (RoomRemoved);

		writes (room);	// name of the room
		}

	string name;

	this (Stream s)
		{
		super (s);

		name = reads ();
		}
	}

class SAdminMessage : Message
	{	// Send an admin message
	this (string message)
		{
		super (AdminMessage);

		writes (message);	// the message
		}

	string message;

	this (Stream s)
		{
		super (s);

		message = reads ();
		}
	}

class SCheckPrivileges : Message
	{	// Tell a client how many seconds of privileges he has left
	this (int time)
		{
		super (CheckPrivileges);

		writei (time);		// time left
		}

	int time;

	this (Stream s)
		{
		super (s);

		time = readi ();
		}
	}

class SSimilarUsers : Message
	{	// Send a list of users with similar tastes
	this (int[string] list)
		{
		super (SimilarUsers);

		writei (list.length);
		foreach (string user, int weight ; list)
			{
			writes (user);
			writei (weight);
			}
		}

	int[string] list;

	this (Stream s)
		{
		super (s);

		int n = readi ();
		for (int i = 0 ; i < n ; i++)
			{
			string user   = reads ();
			int    weight = readi ();

			list[user] = weight;
			}
		}
	}

class SGetItemRecommendations : Message
	{	// Send a list of recommendations for a particular item
	this (string item, int[string] list)
		{
		super (ItemRecommendations);

		writes (item);
		writei (list.length);
		foreach (string item, int weight ; list)
			{
			writes (item);
			writei (weight);
			}
		}

	int[string] list;

	this (Stream s)
		{
		super (s);

		int n = readi ();
		for (int i = 0 ; i < n ; i++)
			{
			string item   = reads ();
			int    weight = readi ();

			list[item] = weight;
			}
		}
	}

class SItemSimilarUsers : Message
	{	// Send a list of users who like an item
	this (string item, string[] list)
		{
		super (ItemSimilarUsers);

		writes (item);
		writei (list.length);
		foreach (string user ; list)
			{
			writes (user);
			}
		}

	string[] list;

	this (Stream s)
		{
		super (s);

		int n = readi ();
		list.length = n;
		for (int i = 0 ; i < n ; i++)
			{
			list[i] = reads ();
			}
		}
	}

class SRoomTicker : Message
	{	// Send the ticker of room room
	this (string room, string[string] tickers)
		{
		super (RoomTicker);

		writes (room);			// name of the room
		writei (tickers.length);	// number of tickers
		foreach (string user, string ticker ; tickers)
			{
			writes (user);		// user name
			writes (ticker);	// ticker content
			}
		}

	string room;
	string[string] tickers;

	this (Stream s)
		{
		super (s);
		
		room = reads ();
		
		int n = readi ();
		for (int i = 0 ; i < n ; i++)
			{
			string user   = reads ();
			string ticker = reads ();

			tickers[user] = ticker;
			}
		}
	}

class SRoomTickerAdd : Message
	{	// A ticker has been added to the room room by the user user
	this (string room, string user, string ticker)
		{
		super (RoomTickerAdd);

		writes (room);		// name of the room
		writes (user);		// user name
		writes (ticker);	// ticker content
		}
	
	string room;
	string user;
	string ticker;

	this (Stream s)
		{
		super (s);

		room   = reads ();
		user   = reads ();
		ticker = reads ();
		}
	}

class SRoomTickerRemove : Message
	{	// User user has removed his ticker from the room room
	this (string room, string user)
		{
		super (RoomTickerRemove);

		writes (room);		// name of the room
		writes (user);		// user name
		}
	
	string room;
	string user;

	this (Stream s)
		{
		super (s);

		room   = reads ();
		user   = reads ();
		}
	}

class SUserPrivileges : Message
	{	// Send the privileges status of user
	this (string username, int privileges)
		{
		super (UserPrivileges);

		writei (privileges);	// user privileges
		writes (username);	// user name
		}

	int    privileges;
	string username;

	this (Stream s)
		{
		super (s);

		privileges = readi ();
		username   = reads ();
		}
	}

class SCantConnectToPeer : Message
	{	// A connection couldn't be established for some message
	this (int token)
		{
		super (CantConnectToPeer);

		writei (token);	// token of the message
		}

	int token;

	this (Stream s)
		{
		super (s);

		token = readi ();
		}
	}

class SServerInfo : Message
	{	// Specific to Soulfind, info about the server
		// int    : number of fields
		// string : field name
		// string : field value
		// string : field name
		// ...
	this (string[string] info)
		{
		super (ServerInfo);
		
		writei (info.length);	// number of fields being sent

		foreach (string field, string value ; info)
			{
			writes (field);
			writes (value);
			}
		}

	string[string] info;

	this (Stream s)
		{
		super (s);

		int n = readi ();
		for (int i = 0 ; i < n ; i++)
			{
			string field = reads ();
			string value = reads ();

			info[field]  = value;
			}
		}
	}

void send_byte (OutBuffer b, byte o)
	{
	b.write (o);
	}

void send_int (OutBuffer b, int i)
	{
	b.write (i);
	}

void send_string (OutBuffer b, string str)
	{
	b.write (cast (int) str.length);
	b.write (str);
	}

