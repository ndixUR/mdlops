#! perl
#
###########################################################
# mdlops.pl version 0.7alpha
# Copyright (C) 2004 Chuck Chargin Jr. (cchargin@comcast.net)
#
# (With some changes by JdNoa (jdnoa@hotmail.com) between
# November 2006 and May 2007.)
#
# (With some more changes by VarsityPuppet and Fair Strides
# (tristongoucher@gmail.com) during January 2016.)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
##########################################################
# History:
#
# July 1 2004:		First public release of MDLOpsM.pm version 0.1
#                
# July 17 2004: 	Added "writerawbinarymdl" and "makeraw" subs 
#               	    for use with replacer functionality (not working yet)
#			    Now supports vertex normals (Thanks JRC24)
#
# August 4, 2004: 	Fixed a division by zero bug in the vertex normals (thanks Svosh)
#
# October 2, 2004:  	version 0.3
#	                    Now ignores overlapping vertices
#        	            fixed a bug that caused some controllers to be ignored (thanks T7nowhere and Svosh)                 
#                	    updated docs on how texture maps work in kotor (thanks T7nowhere and Svosh)
#                  	    updated model tutorial
#                   
# November 18, 2004: 	Version 0.4
#                   	    added replacer function (idea originally suggested to me by tk102)
#                   	    gui does not get built when using command line (thanks Fred Tetra)
#                  	    added ability to rename textures in binary models (thanks darkkender)
#                   	    cool new icon created by Svosh.  Thanks Svosh!
#
# March 8, 2005: 	Version 0.5
#                   	    figured out that some meshes have 2 textures (thanks Fred Tetra)
#                   	    added fix for meshes that have 0 verticies (thanks Fred Tetra)
#                   	    added support for Kotor 2.  The model is bigger by only 8 bytes per mesh!
#                   	    the program will auto-detect if a binary model is from kotor 1 or kotor 2
#                   
# March 9, 2006: 	Version 0.6alpha4
#                   	    Added aabb support (thanks Fred Tetra)
#                   	    Vastly improved ascii import speed (optimized the adjacent face routine)
#                   	    Added partial support for aurora lights
#                   	    ANIMATIONS! MUCH MUCH thanks to JdNoa for her cracking of the compressed quaternion format
#                     	    and for writing the animation delta code!
#
# May 21, 2007:		version 0.6.1alpha1 (changes by JdNoa)
#	                    Added support for compiling animations.  Code mostly ported from Torlack's NWN compiler.
#       	            Added controllers for lights and emitters, but not tested yet.
#
# January 13, 2016:	Version 0.7alpha
#			    Reworked calculations of face normals
#			    Reworked calculations of vertex normals
#
##########################################################
# MUCH MUCH MUCH thanks to Torlack for his NWN MDL info!
# without that this script could not exist!
#
# MUCH MUCH thanks to JdNoa for her cracking of the compressed quaternion format
#
# Thanks to my testers:
#   T7nowhere
#   Svosh
#   Seprithro
#   ChAiNz.2da
#
# file browser dialog added by tk102
#
# Thanks to all at Holowan Laboratories for your input
# and support.
#
# usage:
# command line usage of perl scripts:
# NOTE: you must first copy the MDLOpsM.pm file into your \perl\lib directory
# perl mdlops.pl [-a] [-s] [-k1|-k2] c:\directory\model.mdl
# OR
# perl mdlops.pl [-a] [-s] [-k1|-k2] c:\directory\*.mdl
#
# command line usage of the compiled perl script: 
# mdlops.exe [-a] [-s] [-k1|-k2] c:\directory\model.mdl
# OR
# mdlops.exe [-a] [-s] [-k1|-k2] c:\directory\*.mdl
# 
# For the command line the following switches can be used:
# -a will skip extracting animations
# -s will convert skin to trimesh
# -k1 will output a binary model in kotor 1 format
# -k2 will output a binary model in kotor 2 format
# 
# NOTE: The script automatically detects the type
#       of model.
#
# NOTE: For binary models you must have the .MDL and .MDX
#       in the same directory
#
# NOTE: For importing models with skin mesh into binary format
#       the original model must be in the same directory as
#       model being imported.  See readme for more info.
#
# 1) In a command prompt: perl mdlops.pl OR double click mdlops.exe
# 2) click 'select file'
# 3) browse to directory that has your .mdl file.
#    Select the .mdl and click 'open'
# 4) To quickly convert the model click 'Read and write model'
#    NOTE: The script will automatically detect the model type.
# 5) If you started with a binary file (ex. model.mdl) then the
#    resulting ascii model will be model-ascii.mdl
# 6) If you started with an ascii file (ex. model.mdl) then the
#    resulting binary model will be model-bin.mdl
#
# What is this? (see readme for more info)
# 
# This is a Perl script for converting
# Star Wars Knights of the Old Republic (kotor for short)
# binary models to ascii and back again.
#
# Binary models are converted to an ascii format compatible
# with NeverWinter Nights.
# 
# Features:
# -Automatic detection of model type
# -Automatic detection of model version (kotor 1 or kotor 2)
# -works with trimesh models
# -works with dangly mesh models
# -has limited support for skin mesh models (see readme for more details)
# -replacer: lets you replace a trimesh in binary model with a trimesh from an ascii model
# -renamer: lets you rename textures in a binary model
# 
# Still needs work:
# -exporting light sabers to binary is not supported, exporting to ascii is partially supported
# -exporting models with emitters to binary or ascii is not supported 
# -exporting models with animations to binary is not supported
# -exporting placeables to binary is not supported, exporting to ascii is partially supported
# 
# READ THE README FOR IMPORTANT INFO ON WORKING WITH SKIN MESH!
# 
# read the "Quick tutorial.txt" for a quick and dirty
# explanation of how to get your models into kotor
#
# Dedicated to Cockatiel
#
use strict;
use Tk;               # no relation to tk102
use TK::Tree;
use Tk::Photo;
use Math::Trig;       # quaternions? I have to convert quaternions?
use Win32::FileOp;    # for file browser added by tk102, thanks tk102!
use Win32::Autoglob;  # stupid windows shells don't do globbing!
use MDLOpsM;          # special forces? or just a Perl script?

use vars qw($VERSION);
$VERSION = '0.7alpha';

#this holds all of the Tk objects
our %object;
#this holds the binary model
our $model1;
#this holds the ascii model (replacer only)
our $model2;
#
our $reqversion = 'k2';
our $curversion = '';
our $extractanims = 1;  # 1 = yes extract animations, 0 = do not extract animations
our $convertskin = 0;   # 1 = convert skin to trimesh, 0 = do not convert skin to trimesh
our ($source, $sourcetext);
our ($curwidth, $curheight);
our $usegui;

#perl2exe_exclude MacPerl.pm
#perl2exe_include File/Glob


if ($ARGV[0] eq "") {
  # no command line arguments, so fire up the GUI
  $usegui = "yes";
  $object{'main'} = MainWindow->new;
  $object{'main'}->resizable(0,0);
  $object{'main'}->configure(-title => "MDLOps $VERSION");
  $object{'main'}->iconimage($object{'main'}->Photo(-file=>"icon.bmp", -format=>'bmp'));
  
  our ($maxwidth, $maxheight) = $object{'main'}->maxsize;

  $object{'instructions1'} = $object{'main'}->Label(-text => 'For binary models you must have the .mdl and .mdx in the same directory');
  $object{'instructions2'} = $object{'main'}->Label(-text => 'Output file will be written to the same dir as the source file');
  $object{'sdir'} = $object{'main'}->Label(-text => 'Source dir');
  $object{'direntry'} = $object{'main'}->Entry();
  $object{'readbutton'} = $object{'main'}->Button(-text=>"Read model", -command => \&readmodel);
  $object{'writebutton'} = $object{'main'}->Button(-text=>"Write model", -command => \&writemodel);
  $object{'readandwrite'} = $object{'main'}->Button(-text=>"Read and write model", -command => \&doit);
  $object{'browse'}=$object{'main'}->Button(-text=>"Select file", -command=>[\&browse_for_file, 'direntry']);
  $object{'viewdata'}=$object{'main'}->Button(-text=>"View data", -command=>\&viewdata);
  $object{'openreplacer'}=$object{'main'}->Button(-text=>"Replacer", -command=>\&openreplacer);
  $object{'openrenamer'}=$object{'main'}->Button(-text=>"Renamer", -command=>\&openrenamer);
  $object{'versionk1'}=$object{'main'}->Radiobutton(-text=>"Kotor 1", 
                                              -value => 'k1',
                                              -indicatoron => 'false', 
                -variable => \$reqversion);
  $object{'versionk2'}=$object{'main'}->Radiobutton(-text=>"Kotor 2", 
                                              -value => 'k2',
                                              -indicatoron => 'false', 
                -variable => \$reqversion);
  $object{'animcheck'} = $object{'main'}->Checkbutton(-text => "Extract animations (reading binary or writing ascii)",
                                                      -variable => \$extractanims);
  $object{'skincheck'} = $object{'main'}->Checkbutton(-text => "Convert skin to trimesh (writing ascii only)",
                                                      -variable => \$convertskin);

              
  $object{'instructions1'}->form (-l => '%0',
                                 -r => '%100',
                                 -t => '%0');

  $object{'instructions2'}->form (-l => '%0',
                                 -r => '%100',
                                 -t => [$object{'instructions1'},0]);

  $object{'versionk1'}->form(-l => '%35',
                       -tp => 10,
                       -t => [$object{'instructions2'},0]);

  $object{'versionk2'}->form(-l => '%55',
                       -tp => 10,
                       -t => [$object{'instructions2'},0]);

  $object{'browse'}->form (-t => [$object{'versionk1'},0],
                         -b => [$object{'readbutton'},0],
                         -tp => 10,
                         -l => '%0');

  $object{'direntry'}->form(-t => [$object{'versionk1'},0],
                            -r => '%100',
                            -l => [$object{'browse'},0],
                            -b => [$object{'readbutton'},0],
                            -tp => 10,
                            -lp => 10,
                            -rp => 10);

  $object{'readbutton'}->form(-tp => 10,
                        -l => '%0',
            -lp => 20,
            -bp => 5,
            -b => [$object{'animcheck'},0]);

  $object{'writebutton'}->form(-tp => 10,
                        -l => [$object{'readbutton'},0],
            -lp => 20,
            -bp => 5,
            -b => [$object{'animcheck'},0]);

  $object{'readandwrite'}->form(-tp => 10,
                                -l => [$object{'writebutton'},0],
                    -lp => 20,
                                -bp => 5,
                                -b => [$object{'animcheck'},0]);

  $object{'viewdata'}->form(-tp => 10,
                      -l => [$object{'readandwrite'},0],
                      -lp => 20,
          -bp => 5,
          -b => [$object{'animcheck'},0]);

  $object{'animcheck'}->form(-tp => 1,
                             -b => [$object{'skincheck'},0],
                             -l => '%0');

  $object{'skincheck'}->form(-tp => 1,
                             -l => '%0',
                             -b => '%100');

  $object{'openrenamer'}->form(-rp => 10,
             -l => [$object{'animcheck'},0],
             -lp => 10,
             -b => '%100',
                   -bp => 10);
           
  $object{'openreplacer'}->form(-l => [$object{'openrenamer'},0],
                          -lp => 10,
                          -rp => 10,
              -b => '%100',
                    -bp => 10);

  $object{'main'}->update;
  $object{'main'}->geometry('+' . int($maxwidth/2 - $object{'main'}->width/2) . '+' . int($maxheight/2 - $object{'main'}->height/2)); 

  # create the data viewer windows and its objects
  $object{'dataviewwin'} = $object{'main'}->Toplevel('title' => 'model data viewer');

  $object{'thelist'} = $object{'dataviewwin'}->Scrolled('Tree',-itemtype => 'text',
                                                  -browsecmd => \&displaydata,
                                                  -scrollbars => 'se');

  $object{'hexdata'} = $object{'dataviewwin'}->Scrolled('Listbox', 
                                                -scrollbars => 'e',
                                                -font => 'systemfixed',
                                                -width => 37);

  $object{'chardata'} = $object{'dataviewwin'}->Scrolled('Listbox',
                                                 -scrollbars => 'e',
                                                 -font => 'systemfixed',
                                                 -width => 20);

  $object{'cookeddata'} = $object{'dataviewwin'}->Scrolled('Listbox',
                                                   -scrollbars => 'e',
                                                   -font => 'systemfixed',
                                                   -width => 30);

  $object{'cookeddata'}->form(-t => '%0',
                              -r => '%100',
                              -b => '%100');

  $object{'chardata'}->form(-t => '%0',
                            -r => [$object{'cookeddata'},0],
                            -b => '%100');

  $object{'hexdata'}->form(-t => '%0',
                           -r => [$object{'chardata'},0], 
                           -b => '%100');

  $object{'thelist'}->form(-t => '%0', 
                           -l => '%0', 
                           -r => [$object{'hexdata'},0], 
                           -b => '%100');
  # the data viewer window has been built, now hide it
  $object{'dataviewwin'}->withdraw;
  # override the delete command so it hides the data viewer window
  $object{'dataviewwin'}->protocol('WM_DELETE_WINDOW', [\&withdrawwindow, 'dataviewwin']);

  #create the replacer model selection window
  $object{'repmodselwin'} = $object{'main'}->Toplevel('title' => 'Replacer: model select');
  $object{'repmodselwin'}->protocol('WM_DELETE_WINDOW', [\&withdrawwindow, 'repmodselwin']);
  $object{'repmodselwin'}->withdraw;
  $object{'binbrowse'}=$object{'repmodselwin'}->Button(-text=>"Binary model", 
                                                 -command=>[\&browse_for_file, 'binaryentry']);
  $object{'binaryentry'} = $object{'repmodselwin'}->Entry(-width => 40);
  $object{'ascbrowse'}=$object{'repmodselwin'}->Button(-text=>"Ascii model",
                                                 -command=>[\&browse_for_file, 'asciientry']);
  $object{'asciientry'} = $object{'repmodselwin'}->Entry(-width => 40);
  $object{'repread'} = $object{'repmodselwin'}->Button(-text=>"Read models",
                                                 -command => \&repreadmodel);

  $object{'binbrowse'}->form(-t => '%0',
                       -tp => 5,
           -l => '%0',
           -lp => 5);

  $object{'binaryentry'}->form(-t => '%0',
                         -tp => 10,
             -l => [$object{'binbrowse'},0],
             -lp => 10,
                   -r => '%100',
                   -rp => 5);

  $object{'ascbrowse'}->form(-t => [$object{'binbrowse'},0],
                       -tp => 10,
           -l => '%0',
           -lp => 5);

  $object{'asciientry'}->form(-t => [$object{'binbrowse'},0],
                        -tp => 15,
            -l => [$object{'ascbrowse'},0],
            -lp => 17,
                  -r => '%100',
                  -rp => 5);

  $object{'repread'}->form(-l => '%40',
                     -t => [$object{'asciientry'},0],
         -tp => 10,
               -bp => 10);

  $object{'repmodselwin'}->update;
  $object{'repmodselwin'}->geometry('+' . int($maxwidth/2 - $object{'repmodselwin'}->width/2) . '+' . int($maxheight/2 - $object{'repmodselwin'}->height/2) ); 

     
  # create replacer node selection window
  $object{'repnodeselwin'} = $object{'main'}->Toplevel('title' => 'Replacer: mesh select');
  $object{'repnodeselwin'}->protocol('WM_DELETE_WINDOW', [\&withdrawwindow, 'repnodeselwin']);
  $object{'repnodeselwin'}->withdraw;
  $object{'repnodebaselabel'}=$object{'repnodeselwin'}->Label(-text => 'Base model name:');
  $object{'repnodebaseentry'}=$object{'repnodeselwin'}->Entry(-width => 30);
  $object{'repnodereplace'}=$object{'repnodeselwin'}->Button(-text=>"Do it!",
                                                       -command=>\&replacenodes);
  $object{'repnodereptarg'}=$object{'repnodeselwin'}->Button(-text=>"Set replace target",
                                                       -command=>\&openreptargwin);
  $object{'replacelist'} = $object{'repnodeselwin'}->Scrolled('Listbox', 
                                                              -scrollbars => 'e',
                          -width => 40);

  $object{'replacelist'}->form (-l => '%0',
                          -lp => 10,
              -t => '%0',
              -tp => 10,
              -r => '%100',
              -rp => 10,
              -b => [$object{'repnodebaselabel'},0],
                    -bp => 10);

  $object{'repnodebaselabel'}->form(-l => '%0',
                              -lp => 10,
            -b => [$object{'repnodereplace'},0],
                                    -bp => 10);

  $object{'repnodebaseentry'}->form(-l => [$object{'repnodebaselabel'},0],
                              -lp => 10,
            -r => '%100',
            -rp => 10,
            -b => [$object{'repnodereplace'},0],
            -bp => 10);

  $object{'repnodereptarg'}->form(-l => '%0',
                            -lp => 10,
          -b => '%100',
          -bp => 10);
          
  $object{'repnodereplace'}-> form ( -l => [$object{'repnodereptarg'},0],
                               -lp => 10,
                               -b => '%100',
             -bp => 10);

  $object{'repnodeselwin'}->update;
  $object{'repnodeselwin'}->geometry('+' . (int($maxwidth/2)-285) . '+' . int($maxheight/2 - $object{'repnodeselwin'}->height/2) ); 
         
  # create replacer target sub window
  $object{'repnodetargwin'} = $object{'main'}->Toplevel('title' => 'Replacer: target select');
  $object{'repnodetargwin'}->protocol('WM_DELETE_WINDOW', [\&withdrawwindow, 'repnodetargwin']);
  $object{'repnodetargwin'}->withdraw;
  $object{'targetselect'}=$object{'repnodetargwin'}->Button(-text=>"Select target",
                                                      -command=>\&targetselect);
  $object{'targetlist'} = $object{'repnodetargwin'}->Scrolled('Listbox', 
                                                              -scrollbars => 'e');

  $object{'targetselect'}->form(-l => '%35',
                          -b => '%100',
                                -bp => 10);
                
  $object{'targetlist'}-> form(-l => '%0',
                         -lp => 10,
             -r => '%100',
             -rp => 10,
             -t => '%0',
             -tp => 10,
                   -b => [$object{'targetselect'},0],
                   -bp => 10);

  $object{'repnodetargwin'}->update;
  $object{'repnodetargwin'}->geometry('+' . (int($maxwidth/2)+15) . '+' . int($maxheight/2 - $object{'repnodetargwin'}->height/2) );

  # create renamer window
  $object{'renamerwin'} = $object{'main'}->Toplevel('title' => 'Renamer');
  $object{'renamerwin'}->protocol('WM_DELETE_WINDOW', [\&withdrawwindow, 'renamerwin']);
  $object{'renamerwin'}->withdraw;
  $object{'renamernewnamelabel'}=$object{'renamerwin'}->Label(-text => 'New name:');
  $object{'renamernewname'}=$object{'renamerwin'}->Entry(-width => 30);
  $object{'renamerdoit'}=$object{'renamerwin'}->Button(-text=>"Change name",
                                                       -command=>\&renameit);
  $object{'renamerwrite'}=$object{'renamerwin'}->Button(-text=>"Write model",
                                                       -command=>\&writeit);
  $object{'renamerlist'} = $object{'renamerwin'}->Scrolled('Listbox', 
                                                              -scrollbars => 'e',
                          -width => 40);

  $object{'renamerlist'}->form (-l => '%0',
                          -lp => 10,
              -t => '%0',
              -tp => 10,
              -r => '%100',
              -rp => 10,
              -b => [$object{'renamernewnamelabel'},0],
                    -bp => 10);

  $object{'renamernewnamelabel'}->form(-l => '%0',
                              -lp => 10,
            -b => [$object{'renamerdoit'},0],
                                    -bp => 10);

  $object{'renamernewname'}->form(-l => [$object{'renamernewnamelabel'},0],
                              -lp => 10,
            -r => '%100',
            -rp => 10,
            -b => [$object{'renamerdoit'},0],
            -bp => 10);

  $object{'renamerdoit'}->form(-l => '%0',
                            -lp => 10,
          -b => '%100',
          -bp => 10);

  $object{'renamerwrite'}->form(-l => [$object{'renamerdoit'},0],
                            -lp => 10,
          -b => '%100',
          -bp => 10);
        
  $object{'renamerwin'}->update;
  $object{'renamerwin'}->geometry('+' . int($maxwidth/2 - $object{'renamerwin'}->width/2) . '+' . int($maxheight/2 - $object{'renamerwin'}->height/2) ); 
  
  MainLoop;
} else {
  # we have a command line argument
  $usegui = "no";
  my $counter = 0;
  # we have a command line argument, so try to extract it.
  foreach (@ARGV) {
    if ($_ eq "-a") {
      print("Animations will not be extracted\n");
      $extractanims = 0;
    } elsif ($_ eq "-s") {
      print("Skins will be converted to trimesh\n");
      $convertskin = 1;
    } elsif ($_ eq "-k1") {
      print("binary will be kotor 1\n");
      $reqversion = 'k1';
    } elsif ($_ eq "-k2") {
      print("binary will be kotor 2\n");
      $reqversion = 'k2';
    } else {
      $counter++;
      print("working on model $counter : $_\n");
      #$object{'direntry'}->delete(0, 'end');
      #$object{'direntry'}->insert(0, $_);
      &doit($_);
    }
  }
  print("$counter models processed\n");
}
print("MDLOps exiting!\n");

sub Tk::Error {
  # do nothing - get rid of most of the crap printed to stderr by the background error handler
}

# read in a model
# This routine checks to see if the model is binary or ascii
# then it calls the correct extraction routine
sub readmodel {
  my $option = shift(@_);
  my $filepath = $object{'direntry'}->get;
  $model1 = undef;
  $model2 = undef;
  
  # do a little sanity checking
  if ($filepath eq "") { # the path box is empty!
    &showerror(-2);
    return -2;
  } elsif (! -e $filepath) { # the path does not exist!
    &showerror(-3, $filepath);
    return -3;
  }

  print("-----------------------------------\n");

  $curversion = &modelversion($filepath);
  print("version: " . $curversion . "\n");

  if (&modeltype($filepath) eq "binary") {
    print ("model is binary\n");
    $model1 = &readbinarymdl($filepath, $extractanims, $curversion);  # load the model
    print("building tree view\n");
    &buildtree($object{'thelist'}, $model1);  # populate the data view with the data
    # change the title of the window to show the model status
    $object{'main'}->configure(-title => "MDLOps $VERSION $model1->{'name'} ($model1->{'source'} $curversion source)");
    # disable the version buttons
    #$object{'versionk1'}->configure(-state => 'disabled');
    #$object{'versionk2'}->configure(-state => 'disabled');
  } else {
    print ("model is ascii\n");
    &cleardisplay;  # clear the data view and hide it, data view does not work with ascii files
    $model1 = &readasciimdl($filepath, 1);  # load the model
    $object{'main'}->configure(-title => "MDLOps $VERSION $model1->{'name'} ($model1->{'source'} source)");
    # enable the version buttons
    #$object{'versionk1'}->configure(-state => 'normal');
    #$object{'versionk2'}->configure(-state => 'normal');
  }

  # if the model could not be loaded we get a negative number back
  if ($model1 < 0) {
    &showerror($model1);
    return $model1;
  }

#  $object{'main'}->messageBox(-message => "Model $model1->{'name'} loaded from " . &modeltype($filepath) . " source.", 
#                       -title => "MDLOps status", 
#           -type => 'OK');
  print("Finished reading model\n");
  print("-----------------------------------\n");
}

# write out a model
# The routine checks where the model came from (ascii or binary) then writes out
# the opposite type.  So, a model from ascii source will be written as a binary model.
sub writemodel {
  my $filepath = $object{'direntry'}->get;

  print("-----------------------------------\n");
  if ($model1->{'source'} eq "binary") {
    print ("model is from binary source, writing ascii model\n");
    &writeasciimdl($model1, $convertskin, $extractanims);
  } else {
    print ("model is from ascii source, writing binary model\n");
    &writebinarymdl($model1, $reqversion);
  }
  print("Finished writing model\n");
  print("-----------------------------------\n");
}

# read in a model then write it out in the opposite format
# This routine checks to see if the model is ascii or binary
# then calls the correct routine to load the model.
# If the load completes then it calls the opposite write
# routine to write out the model.  So, if the selected
# is a binary model it will be loaded then written out
# in ascii format.
sub doit {
  # my $option = shift(@_);
  my $buffer;
  my $filepath;

  if ($usegui eq "yes") {
    $filepath = $object{'direntry'}->get;
  } else {
    $filepath = shift(@_);
  }
  
  $model1 = undef;
  $model2 = undef;
  
  # do some sanity checks
  if ($filepath eq "") { # the file box is empty!
    &showerror(-2);
    return -2;
  } elsif ((! -e $filepath)) { # the file does not exist!
    &showerror(-3);
    return -3;
  }

  print("-----------------------------------\n");
  # determine model type and load it, then write out
  # the opposite format
  if (&modeltype($filepath) eq "binary") {
    $curversion = &modelversion($filepath);
    print ("reading binary model\n");
    $model1 = &readbinarymdl($filepath, $extractanims, $curversion);
    print ("writing ascii model\n");
    &writeasciimdl($model1, $convertskin, $extractanims);
    if ($usegui eq "yes") {
      print ("Building tree view\n");
      &buildtree($object{'thelist'}, $model1);
    }
  } else {
    print ("reading ascii model\n");
    if ($usegui eq "yes") {
      &cleardisplay;
    }
    $model1 = &readasciimdl($filepath, 1);
    if ($model1 < 0) {
      &showerror($model1);
      return $model1;
    }
    print ("writing binary model\n");
    &writebinarymdl($model1, $reqversion);
  }
  print("Finished processing model\n");
  print("-----------------------------------\n");
}

# open the renamer window
sub openrenamer {
  # see if there is a loaded model and it is from binary
  if($model1->{'source'} ne "binary") {
    print("Model is not from binary source!\n");
    return;
  }

  my @meshnodes;
  my @texturenames;
  
  $object{'renamerwin'}->configure(-title => "Renamer: $model1->{'name'}");

  # clear out the list box and entry box
  $object{'renamerlist'}->delete(0, 'end');
  $object{'renamernewname'}->delete(0, 'end');
  # fill the list box with any meshes and their textures found in the binary model
  foreach ( sort {$a <=> $b} keys %{$model1->{'nodes'}} ) {
    if ($_ eq 'truenodenum') {next;}
    if ( $model1->{'nodes'}{$_}{'nodetype'} & 32) {
      if ( ! ($model1->{'nodes'}{$_}{'nodetype'} & 512)) { # skip walk meshes
        $object{'renamerlist'}->insert('end', $model1->{'partnames'}[$_] . "=" . $model1->{'nodes'}{$_}{'bitmap'});
      }
    }
  }
  
  $object{'renamerwin'}->deiconify;
  $object{'renamerwin'}->raise;
}

# rename the texture for the currently selected mesh node
sub renameit{
  my $target;
  my $meshname;
  my $texturename;

  $texturename = $object{'renamernewname'}->get;
  
  # do the sanity checks
  $target = $object{'renamerlist'}->curselection;
  if ($target eq "") {
    #print("You must select a target mesh first!\n");
    &showerror(-8);
    return -8;
  } elsif ($texturename eq "") {
    #print("You must enter a new name first!\n");
    &showerror(-10);
    return -10;
  } elsif (length($texturename) > 31) {
    #print("Name must be 31 characters or less!\n");
    &showerror(-9);
    return -9;
  } elsif ($texturename =~ /\s/) {
    #print("Name can't have white space in it!\n");
    &showerror(-11);
    return -11;
  } elsif ($texturename =~ /=/) {
    #print("Name can't have = in it!\n");
    &showerror(-12);
    return -12;
  }

  ($meshname) = split /=/,$object{'renamerlist'}->get($target);

  $object{'renamerlist'}->delete($target);
  $object{'renamerlist'}->insert($target, $meshname . "=" . $texturename);
 
}

# write out a binary model with the textures renamed
sub writeit {
  my $buffer;

  foreach ($object{'renamerlist'}->get(0, 'end')) {
    /(.*)=(.*)/;
    print("mesh=" . $1 . " texture=" . $2 . " " . $model1->{'nodeindex'}{lc($1)} . "\n");
    # get the raw mesh header
    $buffer = $model1->{'nodes'}{ $model1->{'nodeindex'}{lc($1)} }{'subhead'}{'raw'};
    # replace the texture name
    substr($buffer,  88, 32, pack("Z[32]", $2) );
    # write the data back to the model
    $model1->{'nodes'}{ $model1->{'nodeindex'}{lc($1)} }{'subhead'}{'raw'} = $buffer;
  }

  writerawbinarymdl($model1, $curversion);
  $object{'renamerwin'}->withdraw;
  &showerror(-13);

}

# replace the selected nodes
sub replacenodes {
  my @source;
  my @target;
  my $work;
  my $buffer;

  # get the model base name from the entry box
  $work = $object{'repnodebaseentry'}->get;
  # set the model base name 
  if(length($model1->{'name'}) == length($work) ) {
    print("Base model name will be set to: " . $work . "\n");
    # get the raw geoheader
    $buffer = $model1->{'geoheader'}{'raw'};
    # change the model base name
    substr($buffer, 8, 32, pack("Z[32]", $work) );
    # put the changed data back into the raw geoheader
    $model1->{'geoheader'}{'raw'} = $buffer;

    # get the raw part names list
    $buffer = $model1->{'names'}{'raw'};
    # change the aurora base name
    substr($buffer, 0, length($work)+1, pack("Z*", $work) );
    # put the changed data back into the raw part names list
    $model1->{'names'}{'raw'} = $buffer;

    # change the models file name and path
    $work = lc($work);
    $model1->{'filename'} = $work;
    substr($model1->{'filepath+name'}, length($model1->{'filepath+name'}) - length($work), length($work), $work);
  } else {
    #print("Base model name must be " . length($model1->{'name'}) . " characters\n");
    &showerror(-7, length($model1->{'name'}));
    return -7;
  }

  # build the replace list
  foreach ($object{'replacelist'}->get(0, 'end')) {
    /(\S*)( to be replaced by )?(\S*)?/;
    if ($3 ne "") {
      $source[$work] = $1;
      $target[$work] = $3;
      $work++;
    }
  }

  # replace the nodes
  foreach (0..$#source) {
    print("Replacing binary $source[$_] with ascii $target[$_]\n");
    replaceraw($model1, $model2, $source[$_], $target[$_]);
  }
  # write out the new model
  writerawbinarymdl($model1, $curversion);
  $object{'repnodeselwin'}->withdraw;
  &showerror(-13);

}

sub openreplacer {
  $object{'repmodselwin'}->deiconify;
  $object{'repmodselwin'}->raise;
}

# read the selected binary and ascii models for the replacer
sub repreadmodel {
  my $binarypath = $object{'binaryentry'}->get;
  my $asciipath = $object{'asciientry'}->get;
  
  $model1 = undef;
  $model2 = undef;
  $object{'replacelist'}->delete(0, 'end');
  $object{'targetlist'}->delete(0, 'end');

  # do a little sanity checking
  if ($binarypath eq "") { # the path box is empty!
    &showerror(-2);
    return -2;
  } elsif (! -e $binarypath) { # the path does not exist!
    &showerror(-3, $binarypath);
    return -3;
  }
  if ($asciipath eq "") { # the path box is empty!
    &showerror(-2);
    return -2;
  } elsif (! -e $asciipath) { # the path does not exist!
    &showerror(-3, $asciipath);
    return -3;
  }

  # check if binary model is really binary
  if (&modeltype($binarypath) ne "binary") {
    &showerror(-4, $binarypath);
    return -4;
  }
  # check if ascii model is really ascii
  if (&modeltype($asciipath) ne "ascii") {
    &showerror(-5, $asciipath);
    return -5;
  }

  #read the models
  $curversion = &modelversion($binarypath);
  $model1 = &readbinarymdl($binarypath, 1, $curversion);
  #&writerawbinarymdl($model1);
  $model2 = &readasciimdl($asciipath, 0);
    
  # fill the source list box with any trimeshes found in the binary model
  foreach ( sort {$a <=> $b} keys %{$model1->{'nodes'}} ) {
    if ($_ eq 'truenodenum') {next;}
    if ( $model1->{'nodes'}{$_}{'nodetype'} == 33) {
      $object{'replacelist'}->insert('end', $model1->{'partnames'}[$_]);
    }
  }

  # fill the target list box with any trimeshes found in the ascii model
  $object{'targetlist'}->insert('end', "<none>");
  foreach ( sort {$a <=> $b} keys %{$model2->{'nodes'}} ) {
    if ($_ eq 'truenodenum') {next;}
    if ( $model2->{'nodes'}{$_}{'nodetype'} == 33) {
      $object{'targetlist'}->insert('end', $model2->{'partnames'}[$_]);
    }
  }

  # fill in the base model name entry box
  $object{'repnodebaseentry'}->delete('0','end');
  $object{'repnodebaseentry'}->insert('end',$model1->{'name'});
  
  $object{'repmodselwin'}->withdraw;
  
  $object{'repnodeselwin'}->deiconify;
  $object{'repnodeselwin'}->raise;
}

# select the mesh from the ascii model that will replace the mesh in the binary model
sub targetselect {
  if ($object{'targetlist'}->curselection eq "") {
    #print("You must select a target mesh first!\n");
    &showerror(-8);
    return -8;
  }
  
  if ($object{'targetlist'}->get($object{'targetlist'}->curselection) eq "<none>") {
    $object{'replacelist'}->delete($source);
    $object{'replacelist'}->insert($source, "$sourcetext");
  } else {
    $object{'replacelist'}->delete($source);
    $object{'replacelist'}->insert($source, "$sourcetext to be replaced by " . $object{'targetlist'}->get($object{'targetlist'}->curselection));
  }
  
  $object{'repnodetargwin'}->withdraw;
}

# select the mesh from the binary model that is to be replaced
sub openreptargwin {
  $source = $object{'replacelist'}->curselection;
  
  if ($source eq "") {
    #print("You must select a source mesh first!\n");
    &showerror(-6);
    return -6;
  }
  
  ($sourcetext) = split / /,$object{'replacelist'}->get($source);
  
  $object{'repnodetargwin'}->deiconify;
  $object{'repnodetargwin'}->raise;
}

# un-hides the data view window
sub viewdata {
  $object{'dataviewwin'}->deiconify;
}

# routine to hide a window instead of destroying it
sub withdrawwindow {
  $object{shift(@_)}->withdraw;
}

# my simple little error handler
sub showerror {
  my $error = shift @_;
  my $path = shift @_;
  my $message;

  if ($error == -1) {
    $message = "Model has a face with overlapping vertices.";
  } elsif ($error == -2) {
    $message = "You must select a model file first!";
  } elsif ($error == -3) {
    $message = "$path does not exist!";
  } elsif ($error == -4) {
    $message = "$path is not a binary model!";
  } elsif ($error == -5) {
    $message = "$path is not an ascii model!";
  } elsif ($error == -6) {
    $message = "You must select a source mesh first!";
  } elsif ($error == -7) {
    $message = "Name must be $path characters long!";
  } elsif ($error == -8) {
    $message = "You must select a target mesh first!";
  } elsif ($error == -9) {
    $message = "Name must be 31 characters or less!";
  } elsif ($error == -10) {
    $message = "You must enter a new name first!";
  } elsif ($error == -11) {
    $message = "Name can't have white space in it!";
  } elsif ($error == -12) {
    $message = "Name can't have = in it!";
  } elsif ($error == -13) {
    $message = "Done!";
  }
  
  print($message . "\n");
  if($usegui eq "yes") {
    $object{'main'}->messageBox(-message => $message, 
                          -title => "MDLOps status", 
              -type => 'OK');
  }
}

# clear out the data view
sub cleardisplay {
  $object{'dataviewwin'}->withdraw;
  $object{'thelist'}->delete('all');
  $object{'hexdata'}->delete(0,'end');
  $object{'chardata'}->delete(0,'end');
  $object{'cookeddata'}->delete(0,'end');
}

# display the data in the data view window when a tree entry is clicked
sub displaydata {
  my ($loc, $item, $num, $sub1, $sub2, $sub3) = ("","","","","","");
  my (@raw, @chars, @cooked) = ((),(),());
  
  #get the currently selected list item
  $loc = $object{'thelist'}->info('anchor');
  #split the list info at . and stuff it into the variables
  (undef, $item, $num, $sub1, $sub2, $sub3) = split(/\./,$loc);
  #print("$item|$num|$sub1|$sub2|$sub3\n");

  #clear out the list boxes
  $object{'hexdata'}->delete(0,'end');
  $object{'chardata'}->delete(0,'end');
  $object{'cookeddata'}->delete(0,'end');

  
  if ($item eq "nodes" && $sub1 ne "") {
    if ($sub2 eq "") {
      #this is for node headers and node data
      @raw = hexchop($model1->{$item}{$num}{$sub1}{'raw'});
      @chars = charchop($model1->{$item}{$num}{$sub1}{'raw'});
      @cooked = @{$model1->{$item}{$num}{$sub1}{'unpacked'}};
    } else {
      #this is for node arrays and children lists
      @raw = hexchop($model1->{$item}{$num}{$sub2}{'raw'});
      @chars = charchop($model1->{$item}{$num}{$sub2}{'raw'});
      @cooked = @{$model1->{$item}{$num}{$sub2}{'unpacked'}};
    }
  } elsif ($item =~ /^anims/) {
    if ($sub3 ne "") {
      @raw = hexchop($model1->{$item}{$num}{$sub1}{$sub2}{$sub3}{'raw'});
      @chars = charchop($model1->{$item}{$num}{$sub1}{$sub2}{$sub3}{'raw'});
      @cooked = @{$model1->{$item}{$num}{$sub1}{$sub2}{$sub3}{'unpacked'}};
    } elsif ($sub1 eq "geoheader" || $sub1 eq "animheader" || $sub1 eq "animevents") {
      @raw = hexchop($model1->{$item}{$num}{$sub1}{'raw'});
      @chars = charchop($model1->{$item}{$num}{$sub1}{'raw'});
      @cooked = @{$model1->{$item}{$num}{$sub1}{'unpacked'}};
    } elsif ($num eq "indexes") {
      @raw = hexchop($model1->{$item}{$num}{'raw'});
      @chars = charchop($model1->{$item}{$num}{'raw'});
      @cooked = @{$model1->{$item}{$num}{'unpacked'}};
    }
  } elsif ($item eq "namearray" && $num ne "") {
    #this is for the names array and animatios
    if ($num eq "partnames") {
      @raw = hexchop($model1->{'names'}{'raw'});
      @chars = charchop($model1->{'names'}{'raw'});
      @cooked = @{$model1->{'partnames'}};
    } else {
      @raw = hexchop($model1->{$num}{'raw'});
      @chars = charchop($model1->{$num}{'raw'});
      @cooked = @{$model1->{$num}{'unpacked'}};
    }
  } elsif ($item eq "fileheader" || $item eq "geoheader" || $item eq "modelheader") {
    #this is for the simple headers file, geometry and model
    @raw = hexchop($model1->{$item}{'raw'});
    @chars = charchop($model1->{$item}{'raw'});
    @cooked = @{$model1->{$item}{'unpacked'}};
  }

  #tag a number onto the beginning of all the cooked data
  $num = 0;
  $sub2 = 0;
  $sub1 = $object{'thelist'}->info('data', $loc);
  foreach $item (@cooked) {
    if ($sub1 == 1) {
      $item = sprintf("(%03s) %s", $num, $item);
    } else {
      $sub2++;
      if ($sub2 > $sub1) {
        $sub2 = 1;
      }
      $item = sprintf("%03s-%02s %s",$num, $sub2, $item);
    }
    $num++; 
  }

  #fill the listboxes
  $object{'hexdata'}->insert(0, @raw);
  $object{'chardata'}->insert(0, @chars);
  $object{'cookeddata'}->insert(0, @cooked);
}

sub charchop {
  # this sub takes the raw data and outputs text for use in the chardata listbox
  my ($stuff) = @_;
  my ($counter, $work, @lines) = (0,"",());
  my $temp;

  for ($counter = 0; $counter < length($stuff); $counter++) {
    if (($counter != 0) && ($counter % 16 == 0)) {
      push(@lines, $work);
      $work = "";
    } elsif (($counter != 0) && ($counter % 4 == 0)) {
      $work .= "|"
    }
    $temp = substr($stuff, $counter, 1);
    #print($temp);
    if ( ord($temp) > 31 && ord($temp) < 127) {
      $work .= substr($stuff, $counter, 1) ;
    } else {
      $work .= " " ;
    }
  }
  if ($work ne "") {push(@lines, $work)};
  #print("@lines\n");
  return @lines;
}

sub hexchop {
  #this sub takes the raw data and outputs it in hex for use in the hexdata listbox
  my ($stuff) = @_;
  my ($counter, $work, @lines) = (0,"",());

  $stuff = unpack("H*", $stuff);

  for ($counter = 0; $counter < length($stuff); $counter += 8) {
    if (($counter != 0) && ($counter % 32 == 0)) {
      push(@lines, $work);
      $work = "";
    }
    $work .= substr($stuff, $counter, 8) . "|";
  }
  if ($work ne "") {push(@lines, $work)};
  #print("@lines\n");
  return @lines;
}

sub printhex {
  #this sub takes the raw data and outputs hex data for output to the console
  my ($stuff) = @_;
  my $counter = 0;

  $stuff = unpack("H*", $stuff);

  for ($counter = 0; $counter < length($stuff); $counter += 8) {
    if (($counter != 0) && ($counter % 32 == 0)) {print("\n");}
    print(substr($stuff, $counter, 8) . "|");
 }
  print ("\n--> " . tell(MODELMDL));
  print ("\n\n");
}

sub browse_for_file {
  my $target = shift @_;
  
    my %parms=(
                    title => "Open Model File", handle=>0,
                   filters => { 'Model Files' => '*.mdl', 'All Files' => '*.*'},
                   options =>OFN_FILEMUSTEXIST |  OFN_PATHMUSTEXIST);
    my $dialog_name = OpenDialog \%parms;
    unless (-e $dialog_name) { return; }
    $object{$target}->delete('0','end');
    $object{$target}->insert('end',$dialog_name);
}
