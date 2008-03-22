#!/usr/bin/perl -w

# http://www.multik.ru/lib/distfilesclean.perl

# This script can clean up /usr/portage/distfiles from useless files.
# It removes all files not associated in portage system.
# Script looks in portage cache and compare list with "distfiles list"
# if some file not listed in portage cache - it can be removed.
#
# usage: distfilesclean.pl [s] [d] [p]
# s - suppress any output except filenames
# d - delete files
# p - show full path to files

# Script by multik@multik.ru. Released to public domain.
# Version 0.2. unoptimized ;-)

%filelist = (""=>0); # just empty global hash

$silent=0; # keep silence? 0 - no, 1 - yes.
$del=0; # remove files? 0 - no, just show it for me. 1 - yes.
$pt=0; # show full path to files? 0 - no. 1 - yes.

foreach $argnum (0 .. $#ARGV) {
    if($ARGV[$argnum] eq 's') {$silent=1;}
    if($ARGV[$argnum] eq 'd') {$del=1;}
    if($ARGV[$argnum] eq 'p') {$pt=1;}
}

# read packages descriptions and collect file list
sub process_directory{
    opendir(DIR, "/usr/portage/metadata/cache/$fd") # get category content
	|| die "Can't open $fd $!\n";
    @files = sort readdir(DIR);
    closedir DIR;
    for $file (@files) { # open each file
	next if ($file eq '.' || $file eq '..');
	if(!$silent) {printf("Reading %40s\r",$file);}
	open F, "< /usr/portage/metadata/cache/$fd/$file"
	    || die "Can't open $fd/$file";
	@fil= <F>;
	close F;
# now in @fil[3] we have something like
# mirror://gentoo/skey-1.1.5.tar.bz2 doc? ( http://www.ietf.org/rfc/rfc1938.txt )
# or
# ftp://ftp.berlios.de/pub/cdrecord/alpha/cdrtools-2.01a25.tar.bz2 dvdr? ( mirror://gentoo/cdrtools-2.01a25-dvd.patch.bz2 )
# now we extract all filenames from such strings
	for $fil_exp (split(/ /,$fil[3])) {
	    next if (length($fil_exp)<3); # .Z is minimal extension
	    next if (index($fil_exp,'.')<1); # filename must be with .
	    $rf=rindex($fil_exp, '/'); # get position of file name
	    chomp($f=(substr($fil_exp, $rf+1, length($fil_exp)-$rf-1))); # fetch filename
	    $filelist{$f}=1;
	    } #end of fil_exp loop
	} #end of file loop
} #end of process_directory

opendir(DIR,'/usr/portage/metadata/cache/')
    || die "Can't open /usr/portage/metadata/cache/ $!\n";
@firstlevel = sort readdir(DIR);
closedir DIR;

if(!$silent) {print "Processing cache directory ...\n";};

# get list of first level directory (categories)
for $fd (@firstlevel) {
    next if ($fd eq '.' || $fd eq '..');
    process_directory($fd);
}

if(!$silent) {printf("Reading done.%40s\n","");}

opendir(DIR,'/usr/portage/distfiles/')
    || die "Can't open /usr/portage/distfiles/ $!\n";
@firstlevel = sort readdir(DIR);
closedir DIR;

# now we just simply check @filelist and @firstlevel. if something
# in @firstlevel does not exist in @filelist - kill them !

if(!$silent) {if($del) {print "Files to delete:\n";};};
$path="";
if($pt) {$path="/usr/portage/distfiles/";}

for $fd (@firstlevel) {
    next if ($fd eq '.' || $fd eq '..' || $fd eq 'cvs-src');
    if(!exists($filelist{$fd}))
    {
    if($del) { unlink("/usr/portage/distfiles/$fd") or die "Can't delete $fd : $!";
	    print "$path$fd deleted\n";}
	else {print "$path$fd\n";}
    }
}
