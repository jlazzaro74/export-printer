export-printer
==============

A quick script to help copy printers from one Mac system to another. Reads currently
configured printer configuration via lpoptions and builds an lpadmin command that will
add an identically configured printer on any system with the printer drivers installed.

Adds all options into one big lpadmin command because on OS X the lpoptions command does
not correctly update the printer options.

Take this command and push it out over ARD or use it in a checkinstall_script in munki
to add a printer with specific options.

Especially useful for Epson wide format printers, the addition of which by hand can be
quite the PITA.

