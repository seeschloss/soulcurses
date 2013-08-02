module system;

private import std.string, std.c.stdlib, std.string, std.conv;

string getenv (string var)
	{
	return to!string(std.c.stdlib.getenv (std.string.toStringz (var)));
	}
