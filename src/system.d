module system;

private import std.string, core.stdc.stdlib, std.string, std.conv;

string getenv (string var)
	{
	return to!string(getenv(var));
	}
