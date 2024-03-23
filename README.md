# ULib

ULib is a developer library for GMod 13 (https://gmod.facepunch.com/).

ULib provides such features as universal physics, user access lists, and much, much more!

Visit our homepage at https://ulyssesmod.net/.

You can talk to us on our forums at https://forums.ulyssesmod.net/.

## Requirements
ULib requires a working copy of the latest garrysmod, and that's it!

## Installation

### Workshop
ULib's workshop ID is `557962238`. You can subscribe to ULib via Workshop [here](https://steamcommunity.com/sharedfiles/filedetails/?id=557962238).

### Classic
To install ULib, simply extract the files from the downloaded archive to your garrysmod/addons folder.
When you've done this, you should have a file structure like this:

`<garrysmod>/addons/ulib/lua/ULib/init.lua`

`<garrysmod>/addons/ulib/lua/ULib/server/util.lua`

`<garrysmod>/addons/ulib/lua/autorun/ulib_init.lua`

`<garrysmod>/addons/ulib/data/ULib/users.txt`

Please note that installation is the same on dedicated servers.

You absolutely, positively have to do a full server restart after installing the files. A simple map
change will not cut it!

## Usage

Server admins do not "use" ULib, they simply enjoy the benefits it has to offer.
After installing ULib correctly, scripts that take advantage of ULib will take care of the rest.
Rest easy!

## Credits
ULib is brought to you by..

* Brett "Megiddo" Smith - Contact: <megiddo@ulyssesmod.net>
* JamminR - Contact: <jamminr@ulyssesmod.net>
* Stickly Man! - Contact: <sticklyman@ulyssesmod.net>
* MrPresident - Contact: <mrpresident@ulyssesmod.net>

## Changelog
See the [CHANGELOG](CHANGELOG.md) file for information regarding changes between releases.

## Developers

To all developers, I sincerely hope you enjoy what ULib has to offer!
If you have any suggestions, comments, or complaints, please tell us at https://forums.ulyssesmod.net/.

If you want an overview of what's in ULib, please visit the documentation at https://ulyssesmod.net/docs/.
If you find any bugs, you can report them at https://github.com/TeamUlysses/ulib/issues.

All ULib's functions are kept in the table "ULib" to prevent conflicts.

Revisions are kept in the function/variable documentation. If you don't see revisions listed, it hasn't changed since v2.0

If you write a script taking advantage of ULib, stick the init script inside ULib/modules. ULib will load your script after
ULib loads, and will send it to and load it on clients as well.

Some important quirks developers should know about --
* autocomplete - You have to define the autocomplete on the client, so if you pass a string for autocomplete to ULib.concommand,
it will assume you mean a client function. There's also a delay in the sending of these to the client.
