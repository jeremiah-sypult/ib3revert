ib3revert
=========

Attempts to revert XIB changes made by Xcode 5 so that the file can be opened with Xcode 3.2.6.

NO WARRANTY. USE AT YOUR OWN RISK.

Usage
-----
ib3revert <filepath.xib> [-confirm]

This is experimental, unsupported software. There is no guarantee that it will solve any problems. 

Invoking without the -confirm flag will perform a "dry run" without saving. It spews some debug output that vaguely hints at what is going on under the hood.

When you invoke -confirm, the input file is OVERWRITTEN IN PLACE. I hope you have backups or source control. Remember when I said this was experimental, unsupported software? :)


Building & Compiling
--------------------
You can use the included Xcode project to build, or invoke the following command to compile:

clang -o ib3revert ib3revert.m -framework Cocoa


LICENSE
=======

Released under no license. PUBLIC DOMAIN. NO WARRANTY. USE AT YOUR OWN RISK.
http://unlicense.org
