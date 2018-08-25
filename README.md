# Shadow-Tune
Perl script to swap out the soundtrack of Harebrained Scheme's Shadowrun games with custom music. 

[Prerequisites](#prerequisites)

[Installation](#installation)

[Usage](#usage)

[Screenshots](#screenshots)

[Limitations](#limitations)

Need more documentation? Visit the [wiki](https://github.com/Van-Ziegelstein/Shadow-Tune/wiki)!

## What is this exactly?
At its core, *Shadow-Tune* is a tool to manipulate the music resource files of the three
Shadowrun Games released by Harebrained Schemes:

- *Shadowrun Returns*
- *Shadowrun Dragonfall*
- *Shadowrun Hong Kong*

All three games store their music in a file named `resources.assets.resS`, with corresponding
metadata saved in another file labeled `resources.assets`. Users wishing to replace the soundtrack
with something else will have to overwrite the `resources.assets.resS` file with a new one and 
update the aforementioned metadata.

*Shadow-Tune* aims to automate this replacement process. However, it is **not** a music converter and it is
up to the user to provide a properly formatted `resources.assets.resS` file. (More information on how to create
a custom version of this file can be found in the [wiki](https://github.com/Van-Ziegelstein/Shadow-Tune/wiki/FAQ)!)

**Important:**

This is the experimental gui version. It uses a local server daemon and a browser-based interface (if an html form
can already be called such) to hide the nasty commandline stuff. Development is still under way.

## Why does this exist?
*Shadow-Tune* `1.0` was originally developed as part of the effort to bring the UGC campaign [CalFree in Chains](https://steamcommunity.com/sharedfiles/filedetails/?id=1239356669)
(which every self-respecting Shadowrunner should play if he/she/it hasn't already) to Linux platforms. The mod came with its
own soundtrack and a Linux-specific solution was needed to properly apply it and restore vanilla behavior once finished with the campaign.

This branch came into existence when the maintainer contemplated the secrets of bad gui design and decided to open Pandora's Box.

Shadowrunners unite! (Or maybe it would be wiser to flee?)

## Prerequisites
- A Perl interpreter, preferably `>= 5.26.2`.
Most Linux and Unix flavors should come with one pre-installed. Windows users might want to give [Strawberry Perl](http://strawberryperl.com/) or [ActivePerl](https://www.activestate.com/activeperl) a try. (**Note: Only Strawberry Perl has been tested so far. See [Limitations](#limitations) for further information.**)

## Installation
There are no releases yet. If you really want to try this out, then clone the repo. Stability is not guaranteed!

## Usage
Since the main interaction with the user is meant to happen in the gui instead of the
console, the commandline parameters are more limited.

Currently there are two options:

* `-p <port number>`
Specify an alternate port for the server to listen on. (Default is 49003.)

* `--help`
Print the help dialogue to the console.


## Screenshots

| The browser interface | Updating resources.assets of Shadowrun Hong Kong | 
| --- | --- | 
| <img src="screenshots/shadow_tune1.png" width="400" height="250"> | <img src="screenshots/shadow_tune2.png" width="400" height="250"> 

## Limitations
- The script provides no way of accessing and/or modifying individual music tracks, the only available operation
is bulk replacement of everything. This is because even the replacement of only a single track would boil down to
providing a modified `resources.assets.resS` file and performing a standard swap operation. (The number of tracks has to remain
constant otherwise the game will most certainly crash when loading nonexistent music data.)

- *Shadow-Tune* was originally developed in and for a Unix-like environment. This still holds true for the gui branch as well. Nevertheless, Windows compatibility will certainly be a goal for this version.

- A html form? Seriously? Admittedly, a browser-based user interface is not the first solution that comes to mind when thinking about a good gui. The reason for choosing this approach is that Shadow-Tune still aims at introducing as few dependencies as possible. There are solid gui frameworks for Perl but those would require the user to install additional packages. On the other hand, every OS comes with a browser. The operations Shadow-Tune is designed to carry out are still simple enough for a html form to suffice (at least I hope so). On a more historical note, Perl has its roots in web scripting anyway and graphical interfaces never were among the areas where it truly shone. 

## Authors
**Van Ziegelstein** - Creator and Maintainer 

## Acknowledgments
Every Shadowrunner needs the right team for the job and *Shadow-Tune* wouldn't exist without the groundwork laid by two
particular runners:

**Zetor** - Performed the initial research into the sound resources of *Shadowrun Returns* and discovered how `resources.assets`
and `resources.assets.resS` were related.

**Cirion** - Creator of the UGC campaigns *Antumbra Saga*, *Caldecott Caper* and *CalFree in Chains*. Expanded Zetor's research
with regard to the audio format of `resources.assets.resS` and built the first music replacer for *Shadowrun Hong Kong*.

## License
This project is licensed under the [MIT License](LICENSE).
