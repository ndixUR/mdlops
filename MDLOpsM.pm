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
# Thanks to my testers:
#   T7nowhere
#   Svosh
#   Seprithro
#   ChAiNz.2da
#   
# Thanks to all at Holowan Laboratories for your input
# and support.
#
# What is this?
# 
# This is a Perl module that contains functions for 
# importing and extracting models from
# Star Wars Knight of the Old Republic 1 and 2
#
# see the readme for more info
#
# Dedicated to Cockatiel
# 
package MDLOpsM;

use Exporter;
our @EXPORT = qw( modeltype readbinarymdl writeasciimdl readasciimdl writebinarymdl buildtree writerawbinarymdl replaceraw modelversion);
our @ISA = qw(Exporter);
use vars qw($VERSION);
$VERSION = '0.8.0';

#use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use Time::HiRes qw(gettimeofday tv_interval);
use strict;
use Math::Trig;       # quaternions? I have to convert quaternions?

# add helpful debug library from perl core
use Data::Dumper;

# turn this on for maximum verbosity
our $printall = 0;

# for use with $model{'geoheader'}{'unpacked'}[  ]
use constant ROOTNODE => 3;
# use constant NODENUM => 4;
# for use with $model{'modelheader'}{'unpacked'}[  ]
use constant ANIMROOT => 5;
# for use with $model{'nodes'}{0}{'header'}{'unpacked'}[  ]
use constant NODETYPE => 0;
use constant NODEINDEX => 2;
#use constant PARENTNODE => 5;
# for use with $model{'nodes'}{0}{'subhead'}{'unpacked'}[  ]
#use constant DATAEXTLEN => 62;
#use constant TEXTURENUM => 63;
#use constant MDXLOC => 70;
#use constant DATAEXT1LOC => 71;
#use constant DATAEXT2LOC => 72;
#use constant DATAEXT3LOC => 73;
#use constant DATAEXT4LOC => 74;

our %structs;
$structs{'fileheader'} =  {loc =>   0, num =>  3, size =>  4, dnum => 1, name => "file_header",  tmplt => "lll"};
$structs{'geoheader'} =   {loc =>  12, num =>  1, size => 80, dnum => 1, name => "geo_header",   tmplt => "llZ[32]lllllllllCCCC"};
$structs{'modelheader'} = {loc =>  92, num =>  1, size => 88, dnum => 1, name => "model_header", tmplt => "CCCClllllffffffffZ[32]"};
$structs{'nameheader'} =  {loc => 180, num =>  1, size => 28, dnum => 1, name => "name_header",  tmplt => "lllllll"};
$structs{'nameindexes'} = {loc =>   4, num =>  5, size =>  4, dnum => 1, name => "name_indexes", tmplt => "l*"};
$structs{'names'} =       {loc =>  -1, num => -1, size => -1, dnum => 1, name => "names",        tmplt => "Z*"};
$structs{'animindexes'} = {loc =>   5, num =>  6, size =>  4, dnum => 1, name => "anim_indexes", tmplt => "l*"};
$structs{'animheader'} =  {loc =>  -1, num =>  1, size => 56, dnum => 1, name => "anim_header",  tmplt => "ffZ[32]llll"};
$structs{'animevents'} =  {loc =>   3, num =>  4, size => 36, dnum => 1, name => "anim_event",   tmplt => "fZ[32]"};

$structs{'nodeheader'} =  {loc =>  -1, num =>  1, size => 80, dnum => 1, name => "node_header",   tmplt => "SSSSllffffffflllllllll"};
$structs{'nodechildren'} ={loc =>  13, num => 14, size =>  4, dnum => 1, name => "node_children", tmplt => "l*"};

$structs{'subhead'}{'3k1'} =  {loc => -1, num => 1, size =>  92, dnum => 1, name => "light_header",     tmplt => "f[4]L[12]l*"};
#$structs{'subhead'}{'5k1'} =  {loc => -1, num => 1, size => 224, dnum => 1, name => "emitter_header",   tmplt => "f[3]L[5]Z[32]Z[32]Z[32]Z[32]Z[16]L[2]SCZ[37]"};
$structs{'subhead'}{'5k1'} =  {loc => -1, num => 1, size => 224, dnum => 1, name => "emitter_header",   tmplt => "f[3]L[5]Z[32]Z[32]Z[32]Z[32]Z[16]L[2]SCZ[32]CL"};
#$structs{'subhead'}{'33k1'} = {loc => -1, num => 1, size => 332, dnum => 1, name => "trimesh_header",   tmplt => "l[5]f[16]lZ[32]Z[32]l[19]f[6]l[13]SSSSSSf[2]ll"}; # kotor
$structs{'subhead'}{'33k1'} = {loc => -1, num => 1, size => 332, dnum => 1, name => "trimesh_header",   tmplt => "L[5]f[16]LZ[32]Z[32]Z[12]Z[12]L[9]l[3]C[8]lf[4]l[13]SSC[6]SfL[3]"}; # kotor
$structs{'subhead'}{'97k1'} = {loc => -1, num => 1, size => 432, dnum => 1, name => "skin_header",      tmplt => $structs{'subhead'}{'33k1'}->{tmplt} . 'l[16]S*'};
$structs{'subhead'}{'161k1'}= {loc => -1, num => 1, size => 388, dnum => 1, name => "animmesh_header",  tmplt => $structs{'subhead'}{'33k1'}->{tmplt} . 'fL[3]f[9]'};
$structs{'subhead'}{'289k1'}= {loc => -1, num => 1, size => 360, dnum => 1, name => "dangly_header",    tmplt => $structs{'subhead'}{'33k1'}->{tmplt} . 'l[3]f[3]l'};
$structs{'subhead'}{'545k1'} = {loc => -1, num => 1, size => 336, dnum => 1, name => "walkmesh_header", tmplt => $structs{'subhead'}{'33k1'}->{tmplt} . 'l'};
$structs{'subhead'}{'2081k1'}={loc => -1, num => 1, size => 352, dnum => 1, name => "saber_header",     tmplt => $structs{'subhead'}{'33k1'}->{tmplt} . 'l*'};

$structs{'subhead'}{'3k2'} =  {loc => -1, num => 1, size =>  92, dnum => 1, name => "light_header",    tmplt => "f[4]L[12]l*"};
#$structs{'subhead'}{'5k2'} =  {loc => -1, num => 1, size => 224, dnum => 1, name => "emitter_header",  tmplt => "f[3]L[5]Z[32]Z[32]Z[32]Z[32]Z[16]L[2]SCZ[37]"};
$structs{'subhead'}{'5k2'} =  {loc => -1, num => 1, size => 224, dnum => 1, name => "emitter_header",  tmplt => "f[3]L[5]Z[32]Z[32]Z[32]Z[32]Z[16]L[2]SCZ[32]CL"};
#$structs{'subhead'}{'33k2'} = {loc => -1, num => 1, size => 340, dnum => 1, name => "trimesh_header",  tmplt => "l[5]f[16]lZ[32]Z[32]l[19]f[6]l[13]SSSSSSf[2]llll"}; # kotor2
$structs{'subhead'}{'33k2'} = {loc => -1, num => 1, size => 340, dnum => 1, name => "trimesh_header",  tmplt => "L[5]f[16]LZ[32]Z[32]Z[12]Z[12]L[9]l[3]C[8]lf[4]l[13]SSC[6]SL[2]fL[3]"}; # kotor2
$structs{'subhead'}{'97k2'} = {loc => -1, num => 1, size => 440, dnum => 1, name => "skin_header",     tmplt => $structs{'subhead'}{'33k2'}->{tmplt} . 'l[16]S*'};
$structs{'subhead'}{'161k2'}= {loc => -1, num => 1, size => 396, dnum => 1, name => "animmesh_header", tmplt => $structs{'subhead'}{'33k2'}->{tmplt} . 'fL[3]f[9]'};
$structs{'subhead'}{'289k2'}= {loc => -1, num => 1, size => 368, dnum => 1, name => "dangly_header",   tmplt => $structs{'subhead'}{'33k2'}->{tmplt} . 'l[3]f[3]l'};
$structs{'subhead'}{'545k2'}= {loc => -1, num => 1, size => 344, dnum => 1, name => "walkmesh_header", tmplt => $structs{'subhead'}{'33k2'}->{tmplt} . 'l'};
$structs{'subhead'}{'2081k2'}={loc => -1, num => 1, size => 360, dnum => 1, name => "saber_header",    tmplt => $structs{'subhead'}{'33k2'}->{tmplt} . 'l*'};

$structs{'controllers'} =  {loc => 16, num => 17, size => 16, dnum => 9, name => "controllers",     tmplt => "lssssCCCC"};
$structs{'controllerdata'}={loc => 19, num => 20, size =>  4, dnum => 1, name => "controller_data", tmplt => "f*"};

$structs{'data'}{3}[0]={loc =>  1, num =>  2, size =>  0, dnum => 1, name => "unknown",          tmplt => "l*"};
$structs{'data'}{3}[1]={loc =>  4, num =>  5, size =>  0, dnum => 1, name => "flare_sizes",      tmplt => "f*"};
$structs{'data'}{3}[2]={loc =>  7, num =>  8, size =>  0, dnum => 1, name => "flare_pos",        tmplt => "f*"};
$structs{'data'}{3}[3]={loc => 10, num => 11, size =>  0, dnum => 1, name => "flare_color",      tmplt => "f*"};
$structs{'data'}{3}[4]={loc => 13, num => 14, size =>  0, dnum => 1, name => "texture_names",    tmplt => "C*"};
$structs{'data'}{33} = {loc => 78, num => 64, size => 12, dnum => 3, name => "vertcoords",       tmplt => "f*"};
$structs{'data'}{97} = {loc => 78, num => 64, size => 12, dnum => 3, name => "vertcoords",       tmplt => "f*"};
$structs{'data'}{289}= {loc => 78, num => 64, size => 12, dnum => 3, name => "vertcoords",       tmplt => "f*"};
$structs{'data'}{545}= {loc => 78, num => 64, size => 12, dnum => 3, name => "vertcoords",       tmplt => "f*"};
$structs{'data'}{2081}[0] = {loc => 78, num => 64, size => 12, dnum => 3, name => "vertcoords",  tmplt => "f*"};
$structs{'data'}{2081}[1] = {loc => 79, num => 64, size => 12, dnum => 3, name => "vertcoords2", tmplt => "f*"};
$structs{'data'}{2081}[2] = {loc => 80, num => 64, size =>  8, dnum => 2, name => "tverts+",     tmplt => "f*"};
$structs{'data'}{2081}[3] = {loc => 81, num => 64, size => 12, dnum => 2, name => "data2081-3",  tmplt => "f*"};

$structs{'mdxdata'}{33} = {loc => 77, num => 64, size => 24, dnum => 1, name => "mdxdata33",  tmplt => "f*"};
$structs{'mdxdata'}{97} = {loc => 77, num => 64, size => 56, dnum => 1, name => "mdxdata97",  tmplt => "f*"};
$structs{'mdxdata'}{545}= {loc => 77, num => 64, size => 24, dnum => 1, name => "mdxdata545", tmplt => "f*"};
$structs{'mdxdata'}{289}= {loc => 77, num => 64, size => 24, dnum => 1, name => "mdxdata289", tmplt => "f*"};

$structs{'darray'}[0] = {loc =>  2, num =>  3, size => 32, dnum =>  11, name => "faces",            tmplt => "fffflssssss"};
$structs{'darray'}[1] = {loc => 26, num => 27, size =>  4, dnum =>   1, name => "pntr_to_vert_num", tmplt => "l"};
$structs{'darray'}[2] = {loc => 29, num => 30, size =>  4, dnum =>   1, name => "pntr_to_vert_loc", tmplt => "l"};
$structs{'darray'}[3] = {loc => 32, num => 33, size =>  4, dnum =>   1, name => "array3",           tmplt => "l"};

#num and loc for darray4 are extracted from darray1 and darray2 respectively
$structs{'darray'}[4] = {loc => -1, num => -1, size =>  2, dnum =>   3, name => "vertindexes",  tmplt => "s*"};
$structs{'darray'}[5] = {loc => 84, num => 85, size =>  4, dnum =>   1, name => "bonemap",      tmplt => "f"};
$structs{'darray'}[6] = {loc => 86, num => 87, size => 16, dnum =>   4, name => "qbones",       tmplt => "f[4]"};
$structs{'darray'}[7] = {loc => 89, num => 90, size => 12, dnum =>   3, name => "tbones",       tmplt => "f[3]"};
$structs{'darray'}[8] = {loc => 92, num => 93, size =>  4, dnum =>   2, name => "array8",       tmplt => "SS"};
$structs{'darray'}[9] = {loc => 79, num => 80, size => 16, dnum =>   1, name => "constraints+", tmplt => "f[4]"};
$structs{'darray'}[10]= {loc => 79, num => -1, size => 40, dnum =>   6, name => "aabb",         tmplt => "ffffffllll"};

our %nodelookup = ('dummy' => 1, 'light' => 3, 'emitter' => 5, 'trimesh' => 33,
                   'skin' => 97, 'animmesh' => 161, 'danglymesh' => 289, 'aabb' => 545, 'saber' => 2081);

our %classification = ('Effect' => 0x01, 'Tile' => 0x02, 'Character' => 0x04,
                       'Door' => 0x08, 'Lightsaber' => 0x10, 'Placeable' => 0x20, 'Other' => 0x00);

our %reversenode  = reverse %nodelookup;
our %reverseclass = reverse %classification;

# MDX Row data bitmap masks
# The common mesh header contains offsets for 11 different potential row fields,
# 7 have been identified, 6 are (thought) unused in kotor games, 4 are unknown.
use constant MDX_VERTICES               => 0x00000001;
use constant MDX_TEX0_VERTICES          => 0x00000002;
use constant MDX_TEX1_VERTICES          => 0x00000004;
use constant MDX_TEX2_VERTICES          => 0x00000008; # unconfirmed
use constant MDX_TEX3_VERTICES          => 0x00000010; # unconfirmed
use constant MDX_VERTEX_NORMALS         => 0x00000020;
#use constant MDX_???                    => 0x00000040; # unknown
use constant MDX_TANGENT_SPACE          => 0x00000080;
#use constant MDX_???                    => 0x00000100; # unknown
#use constant MDX_???                    => 0x00000200; # unknown
#use constant MDX_???                    => 0x00000400; # unknown
# Type-specific MDX row data:
# the following are all 'made up' and do not appear in vanilla MDXDataBitmap fields,
# they are set while reading type-specific sub-headers from binary models
# so that the MDXDataBitmap will contain a full view of MDX row data
# Skin mesh:
use constant MDX_BONE_WEIGHTS           => 0x00000800;
use constant MDX_BONE_INDICES           => 0x00001000;

# MDX Row definitions
#  bitfield: the mdxdatabitmap value for the data
#  num: the number of floats composing the data
#  offset_i: the index of the data into an array of 11 mdx offsets in the common mesh header (ascii read)
#  offset: the key where the data's row offset is stored in a node (when read from binary)
#  data: the key where the data should be stored in a node (when read from binary)
$structs{'mdxrows'} = [
  { bitfield => MDX_VERTICES,       num => 3, offset_i => 0,  offset => 'mdxvertcoordsloc',  data => 'verts' },
  { bitfield => MDX_VERTEX_NORMALS, num => 3, offset_i => 1,  offset => 'mdxvertnormalsloc', data => 'vertexnormals' },
  { bitfield => MDX_TEX0_VERTICES,  num => 2, offset_i => 3,  offset => 'mdxtex0vertsloc',   data => 'tverts' },
  { bitfield => MDX_TEX1_VERTICES,  num => 2, offset_i => 4,  offset => 'mdxtex1vertsloc',   data => 'tverts1' },
  { bitfield => MDX_TEX2_VERTICES,  num => 2, offset_i => 5,  offset => 'mdxtex2vertsloc',   data => 'tverts2' },
  { bitfield => MDX_TEX3_VERTICES,  num => 2, offset_i => 6,  offset => 'mdxtex3vertsloc',   data => 'tverts3' },
  { bitfield => MDX_TANGENT_SPACE,  num => 9, offset_i => 7,  offset => 'mdxtanspaceloc',    data => 'tangentspace' },
  { bitfield => MDX_BONE_WEIGHTS,   num => 4, offset_i => -1, offset => 'mdxboneweightsloc', data => 'boneweights' },
  { bitfield => MDX_BONE_INDICES,   num => 4, offset_i => -1, offset => 'mdxboneindicesloc', data => 'boneindices' },
];

# Node Type bitmasks
# Types are combinations of these, use for bitwise logic comparisons
use constant NODE_HAS_HEADER    => 0x00000001;
use constant NODE_HAS_LIGHT     => 0x00000002;
use constant NODE_HAS_EMITTER   => 0x00000004;
use constant NODE_HAS_CAMERA    => 0x00000008;
use constant NODE_HAS_REFERENCE => 0x00000010;
use constant NODE_HAS_MESH      => 0x00000020;
use constant NODE_HAS_SKIN      => 0x00000040;
use constant NODE_HAS_ANIM      => 0x00000080;
use constant NODE_HAS_DANGLY    => 0x00000100;
use constant NODE_HAS_AABB      => 0x00000200;
use constant NODE_HAS_SABER     => 0x00000800;

# node types quick reference
# dummy =       NODE_HAS_HEADER =                                   0x001 = 1
# light =       NODE_HAS_HEADER + NODE_HAS_LIGHT =                  0x003 = 3
# emitter =     NODE_HAS_HEADER + NODE_HAS_EMITTER =                0x005 = 5
# reference =   NODE_HAS_HEADER + NODE_HAS_REFERENCE =              0x011 = 17
# mesh =        NODE_HAS_HEADER + NODE_HAS_MESH =                   0x021 = 33
# skin mesh =   NODE_HAS_SKIN + NODE_HAS_MESH + NODE_HAS_HEADER =   0x061 = 97
# anim mesh =   NODE_HAS_ANIM + NODE_HAS_MESH + NODE_HAS_HEADER =   0x0a1 = 161
# dangly mesh = NODE_HAS_DANGLY + NODE_HAS_MESH + NODE_HAS_HEADER = 0x121 = 289
# aabb mesh =   NODE_HAS_AABB + NODE_HAS_MESH + NODE_HAS_HEADER =   0x221 = 545
# saber mesh =  NODE_HAS_SABER + NODE_HAS_MESH + NODE_HAS_HEADER =  0x821 = 2081

# Node Type constants
# These are still used directly sometimes and should be retained for code legibility
use constant NODE_DUMMY         => 1;
use constant NODE_LIGHT         => 3;
use constant NODE_EMITTER       => 5;
use constant NODE_TRIMESH       => 33;
use constant NODE_SKIN          => 97;
use constant NODE_DANGLYMESH    => 289;
use constant NODE_AABB          => 545;
use constant NODE_SABER         => 2081;

# index controllers by node type, since at least one (100) is used twice... gee, thanks, Bioware.
# note that I'm copying emitter and light information from the NWN model format (ie Torlack's NWNMdlComp).  Hopefully it's compatible...
our %controllernames;

$controllernames{+NODE_HAS_HEADER}{8}   = "position";
$controllernames{+NODE_HAS_HEADER}{20}  = "orientation";
$controllernames{+NODE_HAS_HEADER}{36}  = "scale";
$controllernames{+NODE_HAS_HEADER}{132} = "alpha"; # was 128

# got rid of this name because scale was already hardcoded elsewhere
#$controllernames{+NODE_HAS_HEADER}{36}  = "scaling";

# notes from fx_flame01.mdl:
# should be no wirecolor.  missed shadowradius (should be 5). radius, color fine. 
# lightpriority is 5 instead of 4? need: flareradius 30, texturenames 1 _ fxpa_flare, flaresizes 1 _ 3, flarepositions 1 _ 1,
# flarecolorshifts 1 _ 0 0 0.  where did flare 0 come from? missed verticaldisplacement (should be 2).  somehow the nwn model has shadowradius 5 and shadowradius 15.

$controllernames{+NODE_HAS_LIGHT}{76}  = "color";
$controllernames{+NODE_HAS_LIGHT}{88}  = "radius";
$controllernames{+NODE_HAS_LIGHT}{96}  = "shadowradius";
$controllernames{+NODE_HAS_LIGHT}{100} = "verticaldisplacement";
$controllernames{+NODE_HAS_LIGHT}{140} = "multiplier";

# nodes on emitter data: thread called "New/Updated/Corrected Semi Complete Emitter Information by Danmar and BigfootNZ
# http://nwn.bioware.com/forums/viewtopic.html?topic=241936&forum=48
# looks like emitter controllers have been changed around.  changes are guesses based on comparing fx_flame01.mdl...
# thankfully they recompiled at least one model with the new controllers. :)
#fx_flame01.mdl includes these controllers:
# in Flame: 8, 20, 392, 380, 84, 80, 144, 148, 152, 156, 112, 108, 88, 120, 124, 160, 136, 168, 140, 104, 172, 176, 92, 180,
#           184, 188, 192, 128, 132, 96, 100, 116, 164
#should be no alpha.

$controllernames{+NODE_HAS_EMITTER}{80}   = "alphaEnd"; 	# same
$controllernames{+NODE_HAS_EMITTER}{84}   = "alphaStart";	# same - fx_flame01
$controllernames{+NODE_HAS_EMITTER}{88}   = "birthrate"; 	# same - fx_flame01
$controllernames{+NODE_HAS_EMITTER}{92}   = "bounce_co";
$controllernames{+NODE_HAS_EMITTER}{96}   = "combinetime"; 	# was 120
$controllernames{+NODE_HAS_EMITTER}{100}  = "drag";
$controllernames{+NODE_HAS_EMITTER}{104}  = "fps";      	# was 128 - fx_flame01
$controllernames{+NODE_HAS_EMITTER}{108}  = "frameEnd"; 	# was 132 - fx_flame01
$controllernames{+NODE_HAS_EMITTER}{112}  = "frameStart"; 	# was 136
$controllernames{+NODE_HAS_EMITTER}{116}  = "grav";		# was 140
$controllernames{+NODE_HAS_EMITTER}{120}  = "lifeExp";  	# was 144 - fx_flame01 (why did I have 240?)
$controllernames{+NODE_HAS_EMITTER}{124}  = "mass";     	# was 148 -> fx_flame01
$controllernames{+NODE_HAS_EMITTER}{128}  = "p2p_bezier2"; 	# was 152
$controllernames{+NODE_HAS_EMITTER}{132}  = "p2p_bezier3"; 	# was 156
$controllernames{+NODE_HAS_EMITTER}{136}  = "particleRot"; 	# was 160
$controllernames{+NODE_HAS_EMITTER}{140}  = "randvel";    	# was 164 - fx_flame01
$controllernames{+NODE_HAS_EMITTER}{144}  = "sizeStart";  	# was 168 - fx_flame01
$controllernames{+NODE_HAS_EMITTER}{148}  = "sizeEnd";    	# was 172 - fx_flame01 (mass same value)
$controllernames{+NODE_HAS_EMITTER}{152}  = "sizeStart_y"; 	# was 176
$controllernames{+NODE_HAS_EMITTER}{156}  = "sizeEnd_y";  	# was 180
$controllernames{+NODE_HAS_EMITTER}{160}  = "spread";     	# was 184
$controllernames{+NODE_HAS_EMITTER}{164}  = "threshold";  	# was 188
$controllernames{+NODE_HAS_EMITTER}{168}  = "velocity";   	# was 192 - fx_flame01
$controllernames{+NODE_HAS_EMITTER}{172}  = "xsize";      	# was 196
$controllernames{+NODE_HAS_EMITTER}{176}  = "ysize";      	# was 200
$controllernames{+NODE_HAS_EMITTER}{180}  = "blurlength"; 	# was 204 - fx_flame01
$controllernames{+NODE_HAS_EMITTER}{184}  = "lightningDelay"; 	# was 208
$controllernames{+NODE_HAS_EMITTER}{188}  = "lightningRadius"; 	# was 212
$controllernames{+NODE_HAS_EMITTER}{192}  = "lightningScale"; 	# was 216
$controllernames{+NODE_HAS_EMITTER}{196}  = "lightningSubDiv";	#
$controllernames{+NODE_HAS_EMITTER}{200}  = "lightningzigzag";	#
$controllernames{+NODE_HAS_EMITTER}{216}  = "alphaMid";   	# was 464
$controllernames{+NODE_HAS_EMITTER}{220}  = "percentStart"; 	# was 480
$controllernames{+NODE_HAS_EMITTER}{224}  = "percentMid"; 	# was 481
$controllernames{+NODE_HAS_EMITTER}{228}  = "percentEnd"; 	# was 482
$controllernames{+NODE_HAS_EMITTER}{232}  = "sizeMid";    	# was 484
$controllernames{+NODE_HAS_EMITTER}{236}  = "sizeMid_y";   	# was 488
$controllernames{+NODE_HAS_EMITTER}{240}  = "m_fRandomBirthRate"; #
$controllernames{+NODE_HAS_EMITTER}{252}  = "targetsize"; 	#
$controllernames{+NODE_HAS_EMITTER}{256}  = "numcontrolpts"; 	#
$controllernames{+NODE_HAS_EMITTER}{260}  = "controlptradius";	#
$controllernames{+NODE_HAS_EMITTER}{264}  = "controlptdelay"; 	#
$controllernames{+NODE_HAS_EMITTER}{268}  = "tangentspread"; 	#
$controllernames{+NODE_HAS_EMITTER}{272}  = "tangentlength"; 	#
$controllernames{+NODE_HAS_EMITTER}{284}  = "colorMid"; 	# was 468
$controllernames{+NODE_HAS_EMITTER}{380}  = "colorEnd"; 	# was 96 - fx_flame01
$controllernames{+NODE_HAS_EMITTER}{392}  = "colorStart"; 	# was 108 - fx_flame01
$controllernames{+NODE_HAS_EMITTER}{502}  = "detonate"; 	# was 228

$controllernames{+NODE_HAS_MESH}{100} = "selfillumcolor";


##########################################################
# read in the first 4 bytes of a file to see if the model is
# binary or ascii
sub modeltype
{
    my ($filepath) = (@_);
    my $buffer;
  
    open(MODELMDL, $filepath) or die "can't open MDL file: $filepath\n";
    binmode(MODELMDL);
    seek(MODELMDL, 0, 0);

    # read in the first 4 bytes of the file
    read(MODELMDL, $buffer, 4);
    close MODELMDL;
  
    # if the first 4 bytes of the file are nulls we have a binary model
    # else we have an ascii model
    if ($buffer eq "\000\000\000\000")
    {
        return "binary";
    }
    else
    {
        return "ascii";
    }
}

##########################################################
# read in the first 4 bytes of the geometry header to see if the model is
# kotor 1 or kotor 2
sub modelversion
{
    my ($filepath) = (@_);
    my $buffer;
  
    open(MODELMDL, $filepath) or die "can't open MDL file: $filepath\n";
    binmode(MODELMDL);
    seek(MODELMDL, 12, 0);

    # read in the first 4 bytes of the geometry header
    read(MODELMDL, $buffer, 4);
    close MODELMDL;
  
    if (unpack("l",$buffer) eq 4285200)
    {
        return "k2";
    }
    else
    {
        return "k1";
    }
}
##############################################################

#read in a binary model
#
sub readbinarymdl
{
    my ($buffer, $extractanims, $version, $options) = (@_);
    my %model;
    my ($temp, $file, $filepath, %bitmaps);

    # handle options, fill in default values
    if (!defined($options)) {
      $options = {};
    }
    # write animations in ascii model
    if (!defined($options->{extract_anims})) {
      #$options->{extract_anims} = 1;
      # once the UI is updated, remove legacy params
      $options->{extract_anims} = $extractanims;
    }

    #extract just the name of the model
    $buffer =~ /(.*\\)*(.*)\.mdl/;
    $file = $2;
    $model{'filename'} = $2;
  
    $buffer =~ /(.*)\.mdl/;
    $filepath = $1;

    open(MODELMDL, $filepath.".mdl") or die "can't open MDL file: $filepath\n";
    binmode(MODELMDL);

    open(MODELMDX, $filepath.".mdx") or die "can't open MDX file\n";
    binmode(MODELMDX);

    $model{'source'} = "binary";
    $model{'filepath+name'} = $filepath;
  
    #read in the geometry header
    seek(MODELMDL, $structs{'geoheader'}{'loc'},0);
    print("$structs{'geoheader'}{'name'} " . tell(MODELMDL)) if $printall;

    $model{'geoheader'}{'start'} = tell(MODELMDL);
    read(MODELMDL, $buffer, 80);
    print(" " . (tell(MODELMDL) - 1) . "\n") if $printall;

    $model{'geoheader'}{'end'} = tell(MODELMDL)-1;
    $model{'geoheader'}{'raw'} = $buffer;
    $model{'geoheader'}{'unpacked'} = [unpack($structs{'geoheader'}{'tmplt'}, $buffer)];
    $model{'name'} = $model{'geoheader'}{'unpacked'}[2];
    $model{'rootnode'} = $model{'geoheader'}{'unpacked'}[3];
    $model{'totalnumnodes'} = $model{'geoheader'}{'unpacked'}[4];
    $model{'modeltype'} = $model{'geoheader'}{'unpacked'}[12];

    #read in the model header
    print("$structs{'modelheader'}{'name'} " .tell(MODELMDL)) if $printall;
    $model{'modelheader'}{'start'} = tell(MODELMDL);
    read(MODELMDL, $buffer, $structs{'modelheader'}{'size'});
    print(" " . (tell(MODELMDL) - 1) . "\n") if $printall;

    $model{'modelheader'}{'end'} = tell(MODELMDL)-1;
    $model{'modelheader'}{'raw'} = $buffer;
    $model{'modelheader'}{'unpacked'} = [unpack($structs{'modelheader'}{'tmplt'}, $buffer)];
    $model{'classification'} = $reverseclass{$model{'modelheader'}{'unpacked'}[0]};
    $model{'animstart'} = $model{'modelheader'}{'unpacked'}[5];
    $model{'numanims'} = $model{'modelheader'}{'unpacked'}[6];
    $model{'bmin'} = [@{$model{'modelheader'}{'unpacked'}}[9..11]];
    $model{'bmax'} = [@{$model{'modelheader'}{'unpacked'}}[12..14]];
    $model{'radius'} = $model{'modelheader'}{'unpacked'}[15];
    $model{'animationscale'} = $model{'modelheader'}{'unpacked'}[16];
    $model{'supermodel'} = $model{'modelheader'}{'unpacked'}[17];
  
  #$structs{'modelheader'} = {loc =>  92, num =>  1, size => 88, dnum => 1, name => "model_header", tmplt => "CCCClllllffffffffZ[32]"};

    #read in the part name array header
    seek(MODELMDL, $structs{'nameheader'}{'loc'},0);
    print("$structs{'nameheader'}{'name'} " . tell(MODELMDL)) if $printall;
    $model{'nameheader'}{'start'} = tell(MODELMDL);

    read(MODELMDL, $buffer, $structs{'nameheader'}{'size'});
    print(" " . (tell(MODELMDL) - 1) . "\n") if $printall;
    $model{'nameheader'}{'end'} = tell(MODELMDL)-1;
    $model{'nameheader'}{'raw'} = $buffer;
    $model{'nameheader'}{'unpacked'} = [unpack($structs{'nameheader'}{'tmplt'}, $buffer)];
  
    #read in the part name array indexes
    $temp = $model{'nameheader'}{'unpacked'}[$structs{'nameindexes'}{'loc'}] + 12;
    seek(MODELMDL, $temp, 0);
    print("$structs{'nameindexes'}{'name'} " . tell(MODELMDL)) if $printall;

    $model{'nameindexes'}{'start'} = tell(MODELMDL);
    read(MODELMDL, $buffer, $structs{'nameindexes'}{'size'} * $model{'nameheader'}{'unpacked'}[$structs{'nameindexes'}{'num'}]);
    print(" " . (tell(MODELMDL) - 1) . "\n") if $printall;

    $model{'nameindexes'}{'end'} = tell(MODELMDL)-1;
    $model{'nameindexes'}{'raw'} = $buffer;
    $model{'nameindexes'}{'unpacked'} = [unpack($structs{'nameindexes'}{'tmplt'}, $buffer)];

    #read in the part names
    $temp = tell(MODELMDL);
    $model{'names'}{'start'} = tell(MODELMDL);
    print("Array_names $temp") if $printall;

    read(MODELMDL, $buffer, $model{'modelheader'}{'unpacked'}[ANIMROOT] - ($model{'nameheader'}{'unpacked'}[4] + (4 * $model{'nameheader'}{'unpacked'}[5])));
    print(" " . (tell(MODELMDL) - 1) . "\n") if $printall;

    $model{'names'}{'end'} = tell(MODELMDL)-1;
    $model{'names'}{'raw'} = $buffer;
    $model{'partnames'} = [unpack($structs{'names'}{'tmplt'} x $model{'nameheader'}{'unpacked'}[5], $buffer)];

    $temp = 0;
    foreach ( @{$model{'partnames'}} )
    {
        $model{'nodeindex'}{lc($_)} = $temp++;
    }
  
    #read in the geometry nodes
    $model{'nodes'} = {};
    $model{'nodes'}{'truenodenum'} = 0;
    # $tree, $parent, $startnode, $model, $version

    $temp = getnodes('nodes', 'NULL', $model{'geoheader'}{'unpacked'}[ROOTNODE], \%model, $version);

    #read in the animation indexes
    if ($model{'numanims'} != 0 && $options->{extract_anims})
    {
        $temp = $model{'animstart'} + 12;
        seek(MODELMDL, $temp, 0);
        print("Anim_indexes " . tell(MODELMDL)) if $printall;

        $model{'anims'}{'indexes'}{'start'} = tell(MODELMDL);
        read(MODELMDL, $buffer, $structs{'animindexes'}{'size'} * $model{'numanims'});
        print(" " . (tell(MODELMDL) - 1) . "\n") if $printall;

        $model{'anims'}{'indexes'}{'end'} = tell(MODELMDL)-1;
        $model{'anims'}{'indexes'}{'raw'} = $buffer;
        $model{'anims'}{'indexes'}{'unpacked'} = [unpack($structs{'animindexes'}{'tmplt'}, $buffer)];

        #read in the animations
        for (my $i = 0; $i < $model{'numanims'}; $i++)
        {
            #animations start off with a geoheader, so get it
            $temp = $model{'anims'}{'indexes'}{'unpacked'}[$i] + 12;
            seek(MODELMDL, $temp, 0);
            print("Anim_geoheader$i " . tell(MODELMDL)) if $printall;

            $model{'anims'}{$i}{'geoheader'}{'start'} = tell(MODELMDL);
            read(MODELMDL, $buffer, $structs{'geoheader'}{'size'});
            print(" " . (tell(MODELMDL) - 1) . "\n") if $printall;

            $model{'anims'}{$i}{'geoheader'}{'end'}      = tell(MODELMDL)-1;
            $model{'anims'}{$i}{'geoheader'}{'raw'}      = $buffer;
            $model{'anims'}{$i}{'geoheader'}{'unpacked'} = [unpack($structs{'geoheader'}{'tmplt'}, $buffer)];
            $model{'anims'}{$i}{'name'}                  = $model{'anims'}{$i}{'geoheader'}{'unpacked'}[2];

            #next are 56 bytes that is the animation header
            print("Anim_animheader$i " . tell(MODELMDL)) if $printall;

            $model{'anims'}{$i}{'animheader'}{'start'} = tell(MODELMDL);
            read(MODELMDL, $buffer, $structs{'animheader'}{'size'});
            print(" " . (tell(MODELMDL) - 1) . "\n") if $printall;

            $model{'anims'}{$i}{'animheader'}{'end'} = tell(MODELMDL)-1;
            $model{'anims'}{$i}{'animheader'}{'raw'} = $buffer;
            $model{'anims'}{$i}{'animheader'}{'unpacked'} = [unpack($structs{'animheader'}{'tmplt'}, $buffer)];

            $model{'anims'}{$i}{'length'} = $model{'anims'}{$i}{'animheader'}{'unpacked'}[0]; 
            $model{'anims'}{$i}{'transtime'} = $model{'anims'}{$i}{'animheader'}{'unpacked'}[1];
            $model{'anims'}{$i}{'animroot'} = $model{'anims'}{$i}{'animheader'}{'unpacked'}[2];
            $model{'anims'}{$i}{'eventsloc'} = $model{'anims'}{$i}{'animheader'}{'unpacked'}[3]; 
            $model{'anims'}{$i}{'eventsnum'} = $model{'anims'}{$i}{'animheader'}{'unpacked'}[4]; 

            # read in the animation events (if any)
            if ($model{'anims'}{$i}{'eventsnum'} != 0)
            {
                print("anim_event$i " . tell(MODELMDL)) if $printall;

                $model{'anims'}{$i}{'animevents'}{'start'} = tell(MODELMDL);
                $temp = $model{'anims'}{$i}{'eventsnum'};
                read(MODELMDL, $buffer, $structs{'animevents'}{'size'} * $temp);

                $model{'anims'}{$i}{'animevents'}{'raw'} = $buffer;
                $model{'anims'}{$i}{'animevents'}{'unpacked'} = [unpack($structs{'animevents'}{'tmplt'} x $temp,$buffer)];

                foreach(0..($temp - 1))
                {
                    $model{'anims'}{$i}{'animevents'}{'ascii'}[$_] = sprintf(
                        '% .7g %s',
                        $model{'anims'}{$i}{'animevents'}{'unpacked'}[$_ * 2],
                        $model{'anims'}{$i}{'animevents'}{'unpacked'}[($_ * 2) + 1]
                    );
                }
                print(" " . (tell(MODELMDL) - 1) . "\n") if $printall;
                $model{'anims'}{$i}{'animevents'}{'end'} = tell(MODELMDL)-1;
            }      
      
            #next are the animation nodes
            $model{'anims'}{$i}{'nodes'} = {};
            # $tree, $parent, $startnode, $model, $version
            getnodes("anims.$i", 'NULL', $model{'anims'}{$i}{'geoheader'}{'unpacked'}[ROOTNODE], \%model, $version);
        }
    }
    else
    {
        print ("No animations\n") if $printall;
    }

    #write out the bitmaps file
    open(BITMAPSOUT, ">", $filepath."-textures.txt") or die "can't open bitmaps out file\n";
    foreach (0..$model{'nodes'}{'truenodenum'})
    {
        if (defined($model{'nodes'}{$_}{'bitmap'}) && lc($model{'nodes'}{$_}{'bitmap'}) ne "null")
        {
            #print("$_:$model{'nodes'}{$_}{'bitmap'}\n");
            $bitmaps{lc($model{'nodes'}{$_}{'bitmap'})}++;
        }
    }

    foreach (keys %bitmaps)
    {
         print(BITMAPSOUT "$_\n");
    }
    close BITMAPSOUT;

    #open(MODELHINT, ">", $filepath."-out-hint.txt") or die "can't open model hint file\n";

  
    close MODELMDX;
    close MODELMDL;

    return \%model;
}

#######################################################################
# called only by getnodes
# a recursive sub to read in AABB nodes
sub readaabb
{
    my ($ref, $node, $start) = (@_);
    my $buffer;
    my @temp;
    my $count = 1;

  
    seek(MODELMDL, $start, 0);
    read(MODELMDL, $buffer, $structs{'darray'}[10]{'size'});
    $ref->{$node}{ $structs{'darray'}[10]{'name'} }{'raw'} .= $buffer;
    @temp = unpack($structs{'darray'}[10]{'tmplt'}, $buffer);

    #print("Node: " . ($start - 12) . " Child1: " . $temp[6] . " Child2: " . $temp[7] . " Node/leaf: " . $temp[8] . "\n");
  
    if ($temp[6] != 0)
    {
        $count += readaabb($ref, $node, $temp[6] + 12);
    }
  
    if ($temp[7] != 0)
    {
        $count += readaabb($ref, $node, $temp[7] + 12);
    }

    return $count;
}

#######################################################################
# called only by writebinarymdl
# a recursive sub to write AABB nodes
sub writeaabb
{
    my ($ref, $modelnode, $aabbnode, $start) = (@_);
    my ($lastwritepos, $child1, $child2, $buffer, $me);

    $me = $aabbnode;
    #print("aabbnode: " . $aabbnode . " start: " . $start . "|" . $ref->{'nodes'}{$modelnode}{'aabbnodes'}[$aabbnode][6] . "\n");
  
    seek(BMDLOUT, $start, 0);
    $buffer = pack("ffffff", $ref->{'nodes'}{$modelnode}{'aabbnodes'}[$aabbnode][0],
                             $ref->{'nodes'}{$modelnode}{'aabbnodes'}[$aabbnode][1],
                             $ref->{'nodes'}{$modelnode}{'aabbnodes'}[$aabbnode][2],
                             $ref->{'nodes'}{$modelnode}{'aabbnodes'}[$aabbnode][3],
                             $ref->{'nodes'}{$modelnode}{'aabbnodes'}[$aabbnode][4],
                             $ref->{'nodes'}{$modelnode}{'aabbnodes'}[$aabbnode][5]);
    print(BMDLOUT $buffer);
  
    if($ref->{'nodes'}{$modelnode}{'aabbnodes'}[$aabbnode][6] != -1)
    {
        $buffer = pack("llll", 0, 0, $ref->{'nodes'}{$modelnode}{'aabbnodes'}[$aabbnode][6], 0);
        print(BMDLOUT $buffer);
        $lastwritepos = tell(BMDLOUT);
    }
    else
    {
        # calculate start pos for child1 node
        $child1 = $start + 40;

        # write child1 node
        ($aabbnode, $child2) = writeaabb($ref, $modelnode, ($aabbnode + 1), $child1);

        # write child2 node
        ($aabbnode, $lastwritepos) = writeaabb($ref, $modelnode, ($aabbnode + 1), $child2);

        # finish off this node by writing child pointers and rest of data
        seek(BMDLOUT, $start + 24, 0);
        $buffer = pack("llll", ($child1 - 12), ($child2 - 12), -1, 0);
        print(BMDLOUT $buffer);
    }
  
    #print($me . " returning (aabbnode,lastritepos): " . $aabbnode . "|" . $lastwritepos . "\n");
    return ($aabbnode, $lastwritepos);
}
  

#####################################################################
# called only by readbinarymdl
# a recursive sub to read in geometry and animation nodes
sub getnodes {
  my ($tree, $parent, $startnode, $model, $version) = (@_);
  my ($buffer, $work, @children) = ("",1,());
  my ($nodetype, $animnum);
  my ($node, $numchildren, $temp, $temp2, $temp3, $template, $uoffset);  
  my $ref;

  if ($version eq 'k1') {
    # a kotor 1 model
    $uoffset = -2;  # offset for unpacked values
  } elsif ($version eq 'k2') {
    # a kotor 2 model
    $uoffset = 0;
  } else {
    return;
  }
    
  #check if we are called for main nodes or animation nodes
  if ($tree =~ /^anims/) {
    #animations nodes needed.  Find the two hashes and set $ref
    $tree =~ /(.*)\.(.*)/;
    $animnum = $2;
    $ref = $model->{lc($1)}{$animnum}{'nodes'};
  } else {
    #main nodes needed, so just pass the node root hash
    $ref = $model->{lc($tree)};
  }

  $ref->{'truenodenum'}++;
  
  #seek to the start of the node and read in the header
  seek(MODELMDL, $startnode + 12, 0);
  read(MODELMDL, $buffer, $structs{'nodeheader'}{'size'});
  #get the "node number" from the raw data
  $node = unpack("x[ss]s", $buffer);
  $ref->{$node}{'header'}{'raw'} = $buffer;
  $ref->{$node}{'header'}{'unpacked'}  = [unpack($structs{'nodeheader'}{'tmplt'}, $buffer)];
  $temp = $ref->{$node}{'header'}{'unpacked'}[0];
  $temp = $startnode + 12;
  $ref->{$node}{'nodetype'} = $ref->{$node}{'header'}{'unpacked'}[0];
  
  $ref->{$node}{'supernode'} = $ref->{$node}{'header'}{'unpacked'}[1];
  $ref->{$node}{'parent'} = $parent;
  $ref->{$node}{'parentnodenum'} = $model->{'nodeindex'}{lc($parent)};
  $ref->{$node}{'positionheader'} = [@{$ref->{$node}{'subhead'}{'unpacked'}}[6..8]];
  $ref->{$node}{'rotationheader'} = [@{$ref->{$node}{'subhead'}{'unpacked'}}[9..12]]; #quaternion order: w x y z
  $ref->{$node}{'childrenloc'} = $ref->{$node}{'header'}{'unpacked'}[13];
  $ref->{$node}{'childcount'} = $ref->{$node}{'header'}{'unpacked'}[14];
  $ref->{$node}{'controllerloc'} = $ref->{$node}{'header'}{'unpacked'}[16];
  $ref->{$node}{'controllernum'} = $ref->{$node}{'header'}{'unpacked'}[17];
  $ref->{$node}{'controllerdataloc'} = $ref->{$node}{'header'}{'unpacked'}[19];
  $ref->{$node}{'controllerdatanum'} = $ref->{$node}{'header'}{'unpacked'}[20];
  print("$tree-$ref->{$node}{'header'}{'unpacked'}[NODEINDEX]_header " . ($startnode+12) ) if $printall;
  $ref->{$node}{'header'}{'start'} = $startnode+12;
  if ($tree =~ /^anims/) {
    $model->{'nodesort'}{$animnum}{$startnode+12} = $node . "-header";
  }
  print (" " . (tell(MODELMDL) - 1) . "\n") if $printall;
  $ref->{$node}{'header'}{'end'} = tell(MODELMDL) - 1;
  $nodetype = $ref->{$node}{'header'}{'unpacked'}[NODETYPE];

  #record node number in parent's childindexes{nums}
  if (lc($ref->{$node}{'parent'}) ne 'null' &&
      defined($ref->{$ref->{$node}{'parentnodenum'}})) {
    # store actual child index (nodenum) in parent's childindexes, not just locations
    # this gives us a properly traversable tree without having to search by node start location
    push @{$ref->{$ref->{$node}{'parentnodenum'}}{'childindexes'}{'nums'}}, $node;
  }

  #check if node "controller info" has any data to read in
  if ($ref->{$node}{'controllernum'} != 0) {
    $temp = $ref->{$node}{'controllerloc'} + 12;
    seek(MODELMDL, $temp, 0);
    print("$tree-$ref->{$node}{'header'}{'unpacked'}[NODEINDEX]_controllers " . tell(MODELMDL)) if $printall;
    $ref->{$node}{'controllers'}{'start'} = tell(MODELMDL);
    if ($tree =~ /^anims/) {
      $model->{'nodesort'}{$animnum}{tell(MODELMDL)} = $node . "-controllers";
    }

my $dothis = 0;

    read(MODELMDL, $buffer, $structs{'controllers'}{'size'} * $ref->{$node}{'controllernum'});
    print(" " . (tell(MODELMDL)-1) . "\n") if $printall;
    $ref->{$node}{'controllers'}{'end'} = tell(MODELMDL)-1;
    $ref->{$node}{'controllers'}{'raw'} = $buffer;
    $ref->{$node}{'controllers'}{'unpacked'} = [unpack($structs{'controllers'}{'tmplt'} x $ref->{$node}{'controllernum'}, $buffer)];
    $ref->{$node}{'controllers'}{'bezier'} = {};
    for (my $i = 0; $i < $ref->{$node}{'controllernum'}; $i++) {
      if($ref->{$node}{'controllers'}{'unpacked'}[($i * 9)] == 36 && $dothis == 0)
      {
          $dothis = 1;
#          print "Controller data for $node, row $i:\n";
#          print "Piece 1: $ref->{$node}{'controllers'}{'unpacked'}[($i * 9)]\n";
#          print "Piece 2: $ref->{$node}{'controllers'}{'unpacked'}[($i * 9) + 1]\n";
#          print "Piece 3: $ref->{$node}{'controllers'}{'unpacked'}[($i * 9) + 2]\n";
#          print "Piece 4: $ref->{$node}{'controllers'}{'unpacked'}[($i * 9) + 3]\n";
#          print "Piece 5: $ref->{$node}{'controllers'}{'unpacked'}[($i * 9) + 4]\n";
#          print "Piece 6: $ref->{$node}{'controllers'}{'unpacked'}[($i * 9) + 5]\n";
#          print "Piece 7: $ref->{$node}{'controllers'}{'unpacked'}[($i * 9) + 6]\n";
#          print "Piece 8: $ref->{$node}{'controllers'}{'unpacked'}[($i * 9) + 7]\n";
#          print "Piece 9: $ref->{$node}{'controllers'}{'unpacked'}[($i * 9) + 8]\n\n";
      }

      $ref->{$node}{'controllers'}{'cooked'}[$i][0] = $ref->{$node}{'controllers'}{'unpacked'}[($i * 9)];
      $ref->{$node}{'controllers'}{'cooked'}[$i][1] = $ref->{$node}{'controllers'}{'unpacked'}[($i * 9)+1];
      $ref->{$node}{'controllers'}{'cooked'}[$i][2] = $ref->{$node}{'controllers'}{'unpacked'}[($i * 9)+2];
      $ref->{$node}{'controllers'}{'cooked'}[$i][3] = $ref->{$node}{'controllers'}{'unpacked'}[($i * 9)+3];
      $ref->{$node}{'controllers'}{'cooked'}[$i][4] = $ref->{$node}{'controllers'}{'unpacked'}[($i * 9)+4];
      $ref->{$node}{'controllers'}{'cooked'}[$i][5] = $ref->{$node}{'controllers'}{'unpacked'}[($i * 9)+5];
      $ref->{$node}{'controllers'}{'cooked'}[$i][6] = $ref->{$node}{'controllers'}{'unpacked'}[($i * 9)+6];
      $ref->{$node}{'controllers'}{'cooked'}[$i][7] = $ref->{$node}{'controllers'}{'unpacked'}[($i * 9)+7];
      $ref->{$node}{'controllers'}{'cooked'}[$i][8] = $ref->{$node}{'controllers'}{'unpacked'}[($i * 9)+8];
    }
  }

  #check if node "controller data" has any data to read in
  # controller data is a bunch of floats.  The structure to these
  # floats is determined by the controllers above.
  if ($ref->{$node}{'controllerdatanum'} != 0) {
    $temp = $ref->{$node}{'controllerdataloc'} + 12;
    seek(MODELMDL, $temp, 0);
    print("$tree-$ref->{$node}{'header'}{'unpacked'}[NODEINDEX]_$structs{'controllerdata'}{'name'} " . tell(MODELMDL)) if $printall;
    $ref->{$node}{'controllerdata'}{'start'} = tell(MODELMDL);
    if ($tree =~ /^anims/) {
      $model->{'nodesort'}{$animnum}{tell(MODELMDL)} = $node . "-controllerdata";
    }
    read(MODELMDL, $buffer, $structs{'controllerdata'}{'size'} * $ref->{$node}{'controllerdatanum'});
    print(" " . (tell(MODELMDL)-1) . "\n") if $printall;
    $ref->{$node}{'controllerdata'}{'end'} = tell(MODELMDL)-1;
    $ref->{$node}{'controllerdata'}{'raw'} = $buffer;
    $template = "";
    foreach (@{$ref->{$node}{'controllers'}{'cooked'}}) {
      # $_->[0] = controller type
      # $_->[1] = unknown
      # $_->[2] = number of rows of controller data
      # $_->[3] = offset of first time key
      # $_->[4] = offset of first data byte
      # $_->[5] = columns of data
      # the rest is unknown values
      # detect bezier key usage
      my $bezier = 0;
      if ($_->[5] & 16) {
        # this is a bezier keyed controller
        # (according to Torlack and experimental verification)
        $bezier = 1;
        # record a list of the bezierkeyed controllers
        $ref->{$node}{'controllers'}{'bezier'}{$_->[0]} = 1;
      }
      # add template for key time values
      $template .= "f" x $_->[2];
      if ($_->[1] != 128) {
        # check for controller type 20 and column count 2:
        # special compressed quaternion, only read one value here
        if ($_->[0] == 20 && $_->[5] == 2) {
          $template .= "L" x ($_->[2]);
        #} elsif ($_->[0] == 8 && ($_->[5] > 16)) {
        } elsif ($bezier) {
          # bezier key support expands data values to 3 values per column
          $template .= "f" x ( $_->[2] * ( ($_->[5] - 16) * 3) );
        } else {
          $template .= "f" x ($_->[2] * $_->[5]); 
        }
      } else {
        $template .= "s" x (($_->[2] * $_->[5]) * 2); 
      }
    }
    
    $ref->{$node}{'controllerdata'}{'unpacked'} = [unpack($template,$buffer)];
  }

  # cook the controllers
  $temp2 = $ref->{$node}{'controllerdata'}{'unpacked'};
  #for (my $i = 0; $i < $ref->{$node}{'controllerdatanum'}; $i++) {
  foreach (@{$ref->{$node}{'controllers'}{'cooked'}}) {

    #get the controller info
    my ($controllertype, $controllerinfo, $datarows, $timestart, $datastart, $datacolumns) = @{$_}[0..5];

    # check for controller type 20 and column count 2:
    # special compressed quaternion, only read one value here
    if ($controllertype == 20 && $datacolumns == 2) {
      $datacolumns = 1;
    }
    # check for bezier key usage
    if ($datacolumns >= 16 && $datacolumns & 16) {
      $ref->{$node}{'controllers'}{'bezier'}{$controllertype} = 1;
      #$datacolumns &= 0xEF;
      # subtract off the bezier key flag (16)
      $datacolumns -= 16;
      # multiply by values per column (3)
      $datacolumns *= 3;
    }
            
    # loop through the data rows    
    for (my $j = 0; $j < $datarows; $j++) {
      # add keyframe time value to ascii controllers,
      # this is a good time to set precision on controller time values
      $ref->{$node}{'Acontrollers'}{$controllertype}[$j] = sprintf('%.7g', $temp2->[$timestart + $j]);
      $ref->{$node}{'Bcontrollers'}{$controllertype}{'times'}[$j] = $temp2->[$timestart + $j];
      # loop through the datacolumns
      $ref->{$node}{'Bcontrollers'}{$controllertype}{'values'}[$j] = [];
      for (my $k = 0; $k < $datacolumns; $k ++) {
        # add controller data value to ascii controllers
        if ($controllertype == 20 || $controllertype == 8) {
          # further processing, don't set precision (leave in native format)
          $ref->{$node}{'Acontrollers'}{$controllertype}[$j] .= ' ' . $temp2->[$datastart + $k + ($j * $datacolumns)];
        } else {
          # no further processing, set precision now
          $ref->{$node}{'Acontrollers'}{$controllertype}[$j] .= sprintf(" % .7g", $temp2->[$datastart + $k + ($j * $datacolumns)]);
        }
        #$ref->{$node}{'Bcontrollers'}{$controllertype}{'values'}[($j * $datacolumns) + $k] = $temp2->[$datastart + $k + ($j * $datacolumns)];
        push @{$ref->{$node}{'Bcontrollers'}{$controllertype}{'values'}[$j]}, $temp2->[$datastart + $k + ($j * $datacolumns)];
      }
    }
  }

  if ($ref->{$node}{'controllernum'} == 0 && $ref->{$node}{'controllerdatanum'} > 0) {
    $ref->{$node}{'Bcontrollers'}{0}{'values'}[0] = [];
    $ref->{$node}{'Acontrollers'}{0}[0] = "";
    for (my $i = 0; $i < $ref->{$node}{'controllerdatanum'}; $i++) {
      $ref->{$node}{'Acontrollers'}{0}[0] .= " " . $temp2->[$i];
      push @{$ref->{$node}{'Bcontrollers'}{0}{'values'}[0]}, $temp2->[$i];
    }
  }

  # now we have to convert the quaternions to rotation axis and angle.
  # Ever heard of a quaternion?  I didn't until I started this script project!
  # the order of quaternions in controllers is: x y z w

  if (defined($ref->{$node}{'Acontrollers'}{20})) {
    my $quat_prev;
    foreach (@{$ref->{$node}{'Acontrollers'}{20}}) {
      # check for controller type 20 and column count 2:
      # decode the special compressed quaternion
      my @quatVals = split /\s+/;
      if (@quatVals == 2) {
        ($quatVals[0], $quatVals[1]) = @quatVals;     
        $temp = $quatVals[1];

        # extract q.x
        $quatVals[1] = (1.0 - (($temp & 0x7ff) / 1023));

        # extract q.y
        $quatVals[2] = (1.0 - ((($temp >> 11) & 0x7ff) / 1023));

        # extract q.z
        $quatVals[3] = (1.0 - (($temp >> 22) / 511));

        # calculate q.w
        $temp = ($quatVals[1] * $quatVals[1]) + ($quatVals[2] * $quatVals[2]) + ($quatVals[3] * $quatVals[3]);
        if ($temp < 1.0) {
          $quatVals[4] = -sqrt(1.0 - $temp);
        } else {
          # this is for normalizing, I think?
          $temp = sqrt($temp);

          $quatVals[1] = $quatVals[1] / $temp;
          $quatVals[2] = $quatVals[2] / $temp;
          $quatVals[3] = $quatVals[3] / $temp;
          $quatVals[4] = 0.0;
        }
      } # if (@quatVals == 2) {
      # make axis angle animations come out consistently for 3DS
      # quaternions are sign-invariant,
      # but you interpolate between them via shortest angle,
      # certain software can't understand this without a controller 'reset',
      # which this code hopefully makes unnecessary
      my $invert_angle = 0;
      if (defined($quat_prev)) {
        # multiply this quaternion w/ previous inverted
        my $quat_diff = quaternion_multiply(
          \@quatVals,
          [ map { -1 * $_ } @{$quat_prev}[1..3], $quat_prev->[4] ]
        );
        my $qdiff_angle = acos($quat_diff->[3]) * 2;
        if (abs($qdiff_angle) - pi > 0.0001) {
          $invert_angle = 1;
        }
      }
      $quat_prev = [ @quatVals ];
      # now convert quaternions (however we got them) to axis-angle.
      # 2016 replaced w/ better algorithm from:
      # http://www.opengl-tutorial.org/assets/faq_quaternions/index.html
      $temp = $quatVals[4]; # cos_a
      $quatVals[4] = acos($temp) * 2;
      # finish adjustment for 3DS by inverting the angle here
      if ($invert_angle && $quatVals[4] == 0.0) {
        $quatVals[4] = 2.0 * pi;
      } elsif ($invert_angle) {
        $quatVals[4] = ($quatVals[4] / abs($quatVals[4])) * -2.0 * pi + $quatVals[4];
      }
      my $sin_a = sqrt(1.0 - $temp ** 2);
      if (abs($sin_a) < 0.00005) {
          $sin_a = 1;
      }
      $quatVals[1] /= $sin_a;
      $quatVals[2] /= $sin_a;
      $quatVals[3] /= $sin_a;
      $_ = join(' ', map { sprintf('% .7g', $_) } @quatVals);
    } # foreach (@{$ref->{$node}{'Acontrollers'}{20}}) {
  } # if (defined($ref->{$node}{'Acontrollers'}{20})) {

  # Positions in animations are deltas from the initial position.
  if ($tree =~ /^anims/ && defined($ref->{$node}{'Acontrollers'}{8})) {
    my @initialPosVals = split /\s+/, $model->{'nodes'}{$node}{'Acontrollers'}{8}[0];
    # handle bezier key value expansion here. method designed for list like:
    # 0, 1, 2, 3
    # bezier list is like
    # 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
    # 1, 2, 3 are main data,
    # 4, 5, 6 are left control point, 7, 8, 9 are right control handle
    # control handle values are relative to main data values,
    # and located at 1/3 time between keyframes
    foreach (@{$ref->{$node}{'Acontrollers'}{8}}) {
      my @curPosVals = split /\s+/;
      for ($temp = 1; $temp <= 3; $temp++) {
        $curPosVals[$temp] += $initialPosVals[$temp];
      }
      $_ = join(' ', map { sprintf('% .7g', $_) } @curPosVals);
    }
  }

  #check the "node type" and read in the subheader for it
  if ( $nodetype != NODE_DUMMY ) {
    $temp = $startnode + 92;
    seek(MODELMDL, $temp, 0);
    print("$tree-$ref->{$node}{'header'}{'unpacked'}[NODEINDEX]_$structs{'subhead'}{$nodetype . $version}{'name'} " . tell(MODELMDL)) if $printall;
    $ref->{$node}{'subhead'}{'start'} = tell(MODELMDL);
    read(MODELMDL, $buffer, $structs{'subhead'}{$nodetype . $version}{'size'});
    print(" " . (tell(MODELMDL)-1) . "\n") if $printall;
    $ref->{$node}{'subhead'}{'end'} = tell(MODELMDL)-1;
    $ref->{$node}{'subhead'}{'raw'} = $buffer;
    $ref->{$node}{'subhead'}{'unpacked'} = [unpack($structs{'subhead'}{$nodetype . $version}{'tmplt'}, $buffer)];
  }

  if ( $nodetype == NODE_LIGHT ) { # light
    # to do: flare radius, flare sizes array, flare positions array, flare color shifts array, flare texture names char pointer array
    $ref->{$node}{'flareradius'} = $ref->{$node}{'subhead'}{'unpacked'}[0];
    $ref->{$node}{'flaresizesloc'} = $ref->{$node}{'subhead'}{'unpacked'}[4];
    $ref->{$node}{'flaresizesnum'} = $ref->{$node}{'subhead'}{'unpacked'}[5];
    $ref->{$node}{'flarepositionsloc'} = $ref->{$node}{'subhead'}{'unpacked'}[7];
    $ref->{$node}{'flarepositionsnum'} = $ref->{$node}{'subhead'}{'unpacked'}[8];
    $ref->{$node}{'flarecolorshiftsloc'} = $ref->{$node}{'subhead'}{'unpacked'}[10];
    $ref->{$node}{'flarecolorshiftsnum'} = $ref->{$node}{'subhead'}{'unpacked'}[11];
    $ref->{$node}{'texturenamesloc'} = $ref->{$node}{'subhead'}{'unpacked'}[13];
    $ref->{$node}{'texturenamesnum'} = $ref->{$node}{'subhead'}{'unpacked'}[14];

    $ref->{$node}{'lightpriority'} = $ref->{$node}{'subhead'}{'unpacked'}[16];
    $ref->{$node}{'ambientonly'} = $ref->{$node}{'subhead'}{'unpacked'}[17];
    $ref->{$node}{'ndynamictype'} = $ref->{$node}{'subhead'}{'unpacked'}[18];
    $ref->{$node}{'affectdynamic'} = $ref->{$node}{'subhead'}{'unpacked'}[19];
    $ref->{$node}{'shadow'} = $ref->{$node}{'subhead'}{'unpacked'}[20];
    $ref->{$node}{'flare'} = $ref->{$node}{'subhead'}{'unpacked'}[21];
    $ref->{$node}{'fadinglight'} = $ref->{$node}{'subhead'}{'unpacked'}[22];

    # now read any flare data
    # do our reads in commonly laid out order, texturenames, then flare values in ascending order
    if (defined($ref->{$node}{'texturenamesnum'}) && $ref->{$node}{'texturenamesnum'} > 0) {
      $ref->{$node}{'texturenames'} = [];
      $ref->{$node}{'texturenameslength'} = 0;
      #while (scalar(@{$ref->{$node}{'texturenames'}}) < $ref->{$node}{'texturenamesnum'}) {
      for my $name_pointer_num (0..$ref->{$node}{'texturenamesnum'} - 1) {
        # get the pointer at offset
        my $name = '';
        my $name_ptr = 0;
        seek(MODELMDL, ($ref->{$node}{'texturenamesloc'} + 12) + (4 * $name_pointer_num), 0);
        read(MODELMDL, $name_ptr, 4);
        $name_ptr = unpack('L', $name_ptr);
        #print "NAME PTR = $name_ptr\n";
        seek(MODELMDL, $name_ptr + 12, 0);
        read(MODELMDL, $name, 12);
        #print "NAME  = $name " . length($name) . "\n";
        $name = unpack('Z[12]', $name);
        #print "NAME  = $name " . length($name) . "\n";
        $ref->{$node}{'texturenameslength'} += (length($name) + 1); # extra +1 for trailing null
        $ref->{$node}{'texturenames'} = [ @{$ref->{$node}{'texturenames'}}, $name ];
      }
    }

    if (defined($ref->{$node}{'flaresizesnum'}) && $ref->{$node}{'flaresizesnum'} > 0) {
      $ref->{$node}{'flaresizes'} = [];
      $buffer = '';
      for my $flare_size_num (0..$ref->{$node}{'flaresizesnum'} - 1) {
        seek(MODELMDL, ($ref->{$node}{'flaresizesloc'} + 12) + (4 * $flare_size_num), 0);
        read(MODELMDL, $buffer, 4);
        $ref->{$node}{'flaresizes'} = [ @{$ref->{$node}{'flaresizes'}}, unpack('f', $buffer) ];
      }
    }

    if (defined($ref->{$node}{'flarepositionsnum'}) && $ref->{$node}{'flarepositionsnum'} > 0) {
      $ref->{$node}{'flarepositions'} = [];
      $buffer = '';
      for my $flare_position_num (0..$ref->{$node}{'flarepositionsnum'} - 1) {
        seek(MODELMDL, ($ref->{$node}{'flarepositionsloc'} + 12) + (4 * $flare_position_num), 0);
        read(MODELMDL, $buffer, 4);
        $ref->{$node}{'flarepositions'} = [ @{$ref->{$node}{'flarepositions'}}, unpack('f', $buffer) ];
      }
    }

    if (defined($ref->{$node}{'flarecolorshiftsnum'}) && $ref->{$node}{'flarecolorshiftsnum'} > 0) {
      $ref->{$node}{'flarecolorshifts'} = [];
      $buffer = '';
      for my $flare_colorshift_num (0..$ref->{$node}{'flarecolorshiftsnum'} - 1) {
        seek(MODELMDL, ($ref->{$node}{'flarecolorshiftsloc'} + 12) + (12 * $flare_colorshift_num), 0);
        read(MODELMDL, $buffer, 12);
        $ref->{$node}{'flarecolorshifts'} = [ @{$ref->{$node}{'flarecolorshifts'}}, [ unpack('fff', $buffer) ] ];
      }
    }

    # reposition file read position to after light subheader and data
    seek(MODELMDL, $ref->{$node}{'subhead'}{'end'} + (
      ($ref->{$node}{'flaresizesnum'} * 4) +
      ($ref->{$node}{'flarepositionsnum'} * 4) +
      ($ref->{$node}{'flarecolorshiftsnum'} * (4 * 3)) +
      ($ref->{$node}{'texturenamesnum'} * 4) +
      (defined($ref->{$node}{'texturenameslength'})
         ? $ref->{$node}{'texturenameslength'} : 0)
    ), 0);
  }
#tmplt => "f[3]L[5]Z[32]Z[32]Z[32]Z[32]Z[16]L[2]SCZ[32]CL"};
  if ( $nodetype == NODE_EMITTER ) { # emitter
    $ref->{$node}{'deadspace'} = $ref->{$node}{'subhead'}{'unpacked'}[0];
    $ref->{$node}{'blastRadius'} = $ref->{$node}{'subhead'}{'unpacked'}[1];
    $ref->{$node}{'blastLength'} = $ref->{$node}{'subhead'}{'unpacked'}[2];
    $ref->{$node}{'numBranches'} = $ref->{$node}{'subhead'}{'unpacked'}[3];
    $ref->{$node}{'controlptsmoothing'} = $ref->{$node}{'subhead'}{'unpacked'}[4];
    $ref->{$node}{'xgrid'} = $ref->{$node}{'subhead'}{'unpacked'}[5];
    $ref->{$node}{'ygrid'} = $ref->{$node}{'subhead'}{'unpacked'}[6];
    $ref->{$node}{'spawntype'} = $ref->{$node}{'subhead'}{'unpacked'}[7]; #spacetype??
    $ref->{$node}{'update'} = $ref->{$node}{'subhead'}{'unpacked'}[8];
    $ref->{$node}{'render'} = $ref->{$node}{'subhead'}{'unpacked'}[9];
    $ref->{$node}{'blend'} = $ref->{$node}{'subhead'}{'unpacked'}[10];
    $ref->{$node}{'texture'} = $ref->{$node}{'subhead'}{'unpacked'}[11];
    $ref->{$node}{'chunkname'} = $ref->{$node}{'subhead'}{'unpacked'}[12];
    $ref->{$node}{'twosidedtex'} = $ref->{$node}{'subhead'}{'unpacked'}[13];
    $ref->{$node}{'loop'} = $ref->{$node}{'subhead'}{'unpacked'}[14];
    $ref->{$node}{'emitterflags'} = $ref->{$node}{'subhead'}{'unpacked'}[15];
    $ref->{$node}{'m_bFrameBlending'} = $ref->{$node}{'subhead'}{'unpacked'}[16];
    $ref->{$node}{'m_sDepthTextureName'} = $ref->{$node}{'subhead'}{'unpacked'}[17];
    # initial study might point to one or both of these being bitfields aka flags,
    # possibly some of my complete guess flags (or others) are in these.
    $ref->{$node}{'m_bUnknown1'} = $ref->{$node}{'subhead'}{'unpacked'}[18];
    $ref->{$node}{'m_lUnknown2'} = $ref->{$node}{'subhead'}{'unpacked'}[19];

    $ref->{$node}{'p2p'} = ($ref->{$node}{'emitterflags'} & 0x0001) ? 1 : 0;
    $ref->{$node}{'p2p_sel'} = ($ref->{$node}{'emitterflags'} & 0x0002) ? 1 : 0;
    $ref->{$node}{'affectedByWind'} = ($ref->{$node}{'emitterflags'} & 0x0004) ? 1 : 0;
    $ref->{$node}{'m_isTinted'} = ($ref->{$node}{'emitterflags'} & 0x0008) ? 1 : 0;
    $ref->{$node}{'bounce'} = ($ref->{$node}{'emitterflags'} & 0x0010) ? 1 : 0;
    $ref->{$node}{'random'} = ($ref->{$node}{'emitterflags'} & 0x0020) ? 1 : 0;
    $ref->{$node}{'inherit'} = ($ref->{$node}{'emitterflags'} & 0x0040) ? 1 : 0;
    $ref->{$node}{'inheritvel'} = ($ref->{$node}{'emitterflags'} & 0x0080) ? 1 : 0;
    $ref->{$node}{'inherit_local'} = ($ref->{$node}{'emitterflags'} & 0x0100) ? 1 : 0;
    $ref->{$node}{'splat'} = ($ref->{$node}{'emitterflags'} & 0x0200) ? 1 : 0;
    $ref->{$node}{'inherit_part'} = ($ref->{$node}{'emitterflags'} & 0x0400) ? 1 : 0;
    # the following are complete guesses
    $ref->{$node}{'depth_texture'} = ($ref->{$node}{'emitterflags'} & 0x0800) ? 1 : 0;
    $ref->{$node}{'renderorder'} = ($ref->{$node}{'emitterflags'} & 0x1000) ? 1 : 0;
  }
  # subheader flag data snagged from http://nwn-j3d.cvs.sourceforge.net/nwn-j3d/nwn/c-src/mdl2ascii.cpp?revision=1.31&view=markup
  
  if ( $nodetype & NODE_HAS_MESH ) {
    $ref->{$node}{'facesloc'} = $ref->{$node}{'subhead'}{'unpacked'}[2];
    $ref->{$node}{'facesnum'} = $ref->{$node}{'subhead'}{'unpacked'}[3];
    $ref->{$node}{'bboxmin'} = [@{$ref->{$node}{'subhead'}{'unpacked'}}[5..7]];
    $ref->{$node}{'bboxmax'} = [@{$ref->{$node}{'subhead'}{'unpacked'}}[8..10]];
    $ref->{$node}{'radius'} = $ref->{$node}{'subhead'}{'unpacked'}[11];
    $ref->{$node}{'average'} = [@{$ref->{$node}{'subhead'}{'unpacked'}}[12..14]];
    $ref->{$node}{'diffuse'} = [@{$ref->{$node}{'subhead'}{'unpacked'}}[15..17]];
    $ref->{$node}{'ambient'} = [@{$ref->{$node}{'subhead'}{'unpacked'}}[18..20]];
    $ref->{$node}{'transparencyhint'} = $ref->{$node}{'subhead'}{'unpacked'}[21];
    $ref->{$node}{'bitmap'} = $ref->{$node}{'subhead'}{'unpacked'}[22];
    $ref->{$node}{'bitmap2'} = $ref->{$node}{'subhead'}{'unpacked'}[23];
    $ref->{$node}{'texture0'} = $ref->{$node}{'subhead'}{'unpacked'}[24];
    $ref->{$node}{'texture1'} = $ref->{$node}{'subhead'}{'unpacked'}[25];
    $ref->{$node}{'vertnumloc'} = $ref->{$node}{'subhead'}{'unpacked'}[26];
    $ref->{$node}{'vertlocloc'} = $ref->{$node}{'subhead'}{'unpacked'}[29];
    $ref->{$node}{'unknown'} = $ref->{$node}{'subhead'}{'unpacked'}[32];
    # the following 5 things are hypothetical at this point
    $ref->{$node}{'animateuv'} = $ref->{$node}{'subhead'}{'unpacked'}[46];
    $ref->{$node}{'uvdirectionx'} = $ref->{$node}{'subhead'}{'unpacked'}[47];
    $ref->{$node}{'uvdirectiony'} = $ref->{$node}{'subhead'}{'unpacked'}[48];
    $ref->{$node}{'uvjitter'} = $ref->{$node}{'subhead'}{'unpacked'}[49];
    $ref->{$node}{'uvjitterspeed'} = $ref->{$node}{'subhead'}{'unpacked'}[50];
    $ref->{$node}{'mdxdatasize'} = $ref->{$node}{'subhead'}{'unpacked'}[51];
    # the MDX data bitmap contains a bit for each element present in MDX data rows
    $ref->{$node}{'mdxdatabitmap'} = $ref->{$node}{'subhead'}{'unpacked'}[52];
    #$ref->{$node}{'loc61'} = $ref->{$node}{'subhead'}{'unpacked'}[54];
    #$ref->{$node}{'loc62'} = $ref->{$node}{'subhead'}{'unpacked'}[55];
    #$ref->{$node}{'loc65'} = $ref->{$node}{'subhead'}{'unpacked'}[58];
    # offset to vertices in MDX row
    $ref->{$node}{'mdxvertcoordsloc'} = $ref->{$node}{'subhead'}{'unpacked'}[53];
    # offset to vertex normals in MDX row
    $ref->{$node}{'mdxvertnormalsloc'} = $ref->{$node}{'subhead'}{'unpacked'}[54];
    # offset to texture0 tvertices in MDX row
    $ref->{$node}{'mdxtex0vertsloc'} = $ref->{$node}{'subhead'}{'unpacked'}[56];
    # offset to texture1 tvertices in MDX row
    $ref->{$node}{'mdxtex1vertsloc'} = $ref->{$node}{'subhead'}{'unpacked'}[57];
    # offset to texture2 tvertices in MDX row
    $ref->{$node}{'mdxtex2vertsloc'} = $ref->{$node}{'subhead'}{'unpacked'}[58];
    # offset to texture3 tvertices in MDX row
    $ref->{$node}{'mdxtex3vertsloc'} = $ref->{$node}{'subhead'}{'unpacked'}[59];
    # offset to tangent space (bumpmap) info in MDX row
    $ref->{$node}{'mdxtanspaceloc'} = $ref->{$node}{'subhead'}{'unpacked'}[60];

    $ref->{$node}{'vertcoordnum'} = $ref->{$node}{'subhead'}{'unpacked'}[64];
    $ref->{$node}{'texturenum'} = $ref->{$node}{'subhead'}{'unpacked'}[65];

    $ref->{$node}{'lightmapped'} = $ref->{$node}{'subhead'}{'unpacked'}[66];
    $ref->{$node}{'rotatetexture'} = $ref->{$node}{'subhead'}{'unpacked'}[67];
    $ref->{$node}{'m_bIsBackgroundGeometry'} = $ref->{$node}{'subhead'}{'unpacked'}[68];
    $ref->{$node}{'shadow'} = $ref->{$node}{'subhead'}{'unpacked'}[69];
    $ref->{$node}{'beaming'} = $ref->{$node}{'subhead'}{'unpacked'}[70];
    $ref->{$node}{'render'} = $ref->{$node}{'subhead'}{'unpacked'}[71];

    if ($uoffset == 0) {
        # SLL 72,73,74 = should be CCSSCCCC
        my $k2_fields = [ unpack('CCSSCCCC', pack('SLL',  @{$ref->{$node}{'subhead'}{'unpacked'}}[72..74])) ];
        # kotor2 specific things: dirt_enabled, dirt_texture, dirt_worldspace, hologram_donotdraw
        # these are not specifically/correctly unpacked by the main template
        #$ref->{$node}{'dirt_enabled'} = unpack('C', pack('C[2]', $ref->{$node}{'subhead'}{'unpacked'}[72]));
        $ref->{$node}{'dirt_enabled'}    = $k2_fields->[0];
        $ref->{$node}{'dirt_texture'}    = $k2_fields->[2];
        $ref->{$node}{'dirt_worldspace'} = $k2_fields->[3];
        # prevent tongue & teeth from showing up inside closed mouths in holograms:
        $ref->{$node}{'hologram_donotdraw'} = $k2_fields->[4];
        #$ref->{$node}{'hologram_donotdraw'} = $ref->{$node}{'subhead'}{'unpacked'}[74] % 2;
    }

    #XXX not sure this is really a thing ... testing:
    $ref->{$node}{'totalarea'} = $ref->{$node}{'subhead'}{'unpacked'}[75 + $uoffset];

    $ref->{$node}{'MDXdataloc'} = $ref->{$node}{'subhead'}{'unpacked'}[77 + $uoffset];
    $ref->{$node}{'vertcoordloc'} = $ref->{$node}{'subhead'}{'unpacked'}[78 + $uoffset];
    if ( $nodetype == NODE_DANGLYMESH ) {
      $ref->{$node}{'displacement'} = $ref->{$node}{'subhead'}{'unpacked'}[82 + $uoffset];
      $ref->{$node}{'tightness'} = $ref->{$node}{'subhead'}{'unpacked'}[83 + $uoffset];
      $ref->{$node}{'period'} = $ref->{$node}{'subhead'}{'unpacked'}[84 + $uoffset];
    } elsif ( $nodetype == NODE_SKIN ) {
      # MDX row offsets for skin-specific data, bone weights & bone indices
      $ref->{$node}{'mdxboneweightsloc'} = $ref->{$node}{'subhead'}{'unpacked'}[82 + $uoffset];
      $ref->{$node}{'mdxboneindicesloc'} = $ref->{$node}{'subhead'}{'unpacked'}[83 + $uoffset];
      $ref->{$node}{'mdxdatabitmap'} |= MDX_BONE_WEIGHTS | MDX_BONE_INDICES;
      # weights
      $ref->{$node}{'weightsloc'} = $ref->{$node}{'subhead'}{'unpacked'}[84 + $uoffset];
      $ref->{$node}{'weightsnum'} = $ref->{$node}{'subhead'}{'unpacked'}[85 + $uoffset];
      # qbone_ref_inv
      $ref->{$node}{'qbone_ref_invloc'} = $ref->{$node}{'subhead'}{'unpacked'}[86 + $uoffset];
      $ref->{$node}{'qbone_ref_invnum'} = $ref->{$node}{'subhead'}{'unpacked'}[87 + $uoffset];
      # tbone_ref_inv
      $ref->{$node}{'tbone_ref_invloc'} = $ref->{$node}{'subhead'}{'unpacked'}[89 + $uoffset];
      $ref->{$node}{'tbone_ref_invnum'} = $ref->{$node}{'subhead'}{'unpacked'}[90 + $uoffset];
      # boneconstantindices
      $ref->{$node}{'boneconstantindicesloc'} = $ref->{$node}{'subhead'}{'unpacked'}[92 + $uoffset];
      $ref->{$node}{'boneconstantindicesnum'} = $ref->{$node}{'subhead'}{'unpacked'}[93 + $uoffset];
    } elsif ( $nodetype == NODE_AABB ) {
      $ref->{$node}{'aabbloc'} = $ref->{$node}{'subhead'}{'unpacked'}[79 + $uoffset];
    } elsif ( $nodetype == NODE_SABER) {
      # don't yet know much about these values, but let's record them so we can start using them
      $ref->{$node}{'saber1loc'} = $ref->{$node}{'subhead'}{'unpacked'}[79 + $uoffset];
      $ref->{$node}{'saber2loc'} = $ref->{$node}{'subhead'}{'unpacked'}[80 + $uoffset];
      $ref->{$node}{'saber3loc'} = $ref->{$node}{'subhead'}{'unpacked'}[81 + $uoffset];
      $ref->{$node}{'saber_num1'} = $ref->{$node}{'subhead'}{'unpacked'}[82 + $uoffset]; # ???
      $ref->{$node}{'saber_num2'} = $ref->{$node}{'subhead'}{'unpacked'}[83 + $uoffset]; # ???
    }
  } # if 97 or 33 or 289 or 2081
  
  # if we have "node type 33" or "node type 2081" or "node type 97" 
  # read in the vertex coordinates
  #print("vertcoordnum: " . $ref->{$node}{'vertcoordnum'} . "\n");
  
  if ($nodetype & NODE_HAS_SABER) {
    #node type 2081 seems to have 4 vertex data sections
    for (my $i = 0; $i < 4; $i++) {
      $temp = $ref->{$node}{'subhead'}{'unpacked'}[$structs{'data'}{$nodetype}[$i]{'loc'} + $uoffset] + 12;
      seek(MODELMDL, $temp, 0);
      print("$tree-$ref->{$node}{'header'}{'unpacked'}[NODEINDEX]_" . $structs{'data'}{$nodetype}[$i]{'name'} . " " . tell(MODELMDL)) if $printall;
      $ref->{$node}{$structs{'data'}{$nodetype}[$i]{'name'}}{'start'} = tell(MODELMDL);
      $temp = $ref->{$node}{'subhead'}{'unpacked'}[$structs{'data'}{$nodetype}[$i]{'num'}] * ($structs{'data'}{$nodetype}[$i]{'size'});
      read(MODELMDL, $buffer, $temp);
      print(" " . (tell(MODELMDL)-1) . "\n") if $printall;
      $ref->{$node}{$structs{'data'}{$nodetype}[$i]{'name'}}{'end'} = tell(MODELMDL)-1;
      $ref->{$node}{$structs{'data'}{$nodetype}[$i]{'name'}}{'raw'} = $buffer;
      if ($i == 6) {
        $temp = $ref->{$node}{'subhead'}{'unpacked'}[$structs{'data'}{$nodetype}[$i]{'num'}];
        $template = "f" x $temp . "s" x $temp;
      } else {
        $template = $structs{'data'}{$nodetype}[$i]{'tmplt'};
      }
      $ref->{$node}{$structs{'data'}{$nodetype}[$i]{'name'}}{'unpacked'} = [unpack($template, $buffer)];
    }
  } elsif ( ($nodetype & NODE_HAS_MESH) && ($ref->{$node}{'vertcoordnum'} > 0) ) {
    $temp = $ref->{$node}{'vertcoordloc'} + 12;
    seek(MODELMDL, $temp, 0);
    print($tree . "-" . $ref->{$node}{'header'}{'unpacked'}[NODEINDEX] . "_" . $structs{'data'}{$nodetype}{'name'} . " " . tell(MODELMDL)) if $printall;
    $ref->{$node}{'vertcoords'}{'start'} = tell(MODELMDL);
    $temp = $ref->{$node}{'vertcoordnum'} * $structs{'data'}{$nodetype}{'size'};
    read(MODELMDL, $buffer, $temp);
    print(" " . (tell(MODELMDL)-1) . "\n") if $printall;
    $ref->{$node}{'vertcoords'}{'end'} = tell(MODELMDL)-1;
    $ref->{$node}{'vertcoords'}{'raw'} = $buffer;
    $ref->{$node}{'vertcoords'}{'unpacked'} = [unpack($structs{'data'}{$nodetype}{'tmplt'}, $buffer)];
  } # if 2081 elsif 33 or 97 or 289 or 545

  # read in any arrays found in node subhead
  if ($nodetype & NODE_HAS_MESH)  {
    for (my $i = 0; $i < 10; $i++ ) {
      # data arrays 0-4 do not need the k1/k2 offest correction
      if ($i < 5) {
        $temp2 = 0;
      } else {
        $temp2 = $uoffset;
      }   
      if ($ref->{$node}{'subhead'}{'unpacked'}[$structs{'darray'}[$i]{'num'} + $temp2] != 0 && $i != 4) {
        if ($i == 5 && ($nodetype & NODE_HAS_DANGLY)) {next;}      
        if ($i == 9 && !($nodetype & NODE_HAS_DANGLY)) {next;}
        $temp = $ref->{$node}{'subhead'}{'unpacked'}[$structs{'darray'}[$i]{'loc'} + $temp2] + 12;
        seek(MODELMDL, $temp, 0);
        print("$tree-$ref->{$node}{'header'}{'unpacked'}[NODEINDEX]_$structs{'darray'}[$i]{'name'} " . tell(MODELMDL)) if $printall;
        $ref->{$node}{$structs{'darray'}[$i]{'name'}}{'start'} = tell(MODELMDL);
        read(MODELMDL, $buffer, $ref->{$node}{'subhead'}{'unpacked'}[$structs{'darray'}[$i]{'num'} + $temp2] * $structs{'darray'}[$i]{'size'});
        print(" " . (tell(MODELMDL)-1) . "\n") if $printall;
        $ref->{$node}{$structs{'darray'}[$i]{'name'}}{'end'} = tell(MODELMDL)-1;
        $ref->{$node}{$structs{'darray'}[$i]{'name'}}{'raw'} = $buffer;
        $temp = $ref->{$node}{'subhead'}{'unpacked'}[$structs{'darray'}[$i]{'num'} + $temp2];
        $ref->{$node}{$structs{'darray'}[$i]{'name'}}{'unpacked'} = [unpack($structs{'darray'}[$i]{'tmplt'} x $temp, $buffer)];
      }
    }
    # "data array4" is actually pointed to by "data array1" and "data array2"
    # so yes it is strictly not really a data array, but I don't want another
    # list branch yet.
    if ($ref->{$node}{'subhead'}{'unpacked'}[$structs{'darray'}[2]{'num'}] != 0) {
      #if we have a "data array2" then we have a "data array4" so read it in
      # "data array2" holds the location of "data array4"
      $temp = $ref->{$node}{$structs{'darray'}[2]{'name'}}{'unpacked'}[0] + 12;
      seek(MODELMDL, $temp, 0);
      print("$tree-$ref->{$node}{'header'}{'unpacked'}[NODEINDEX]_$structs{'darray'}[4]{'name'} " . tell(MODELMDL)) if $printall;
      $ref->{$node}{$structs{'darray'}[4]{'name'}}{'start'} = tell(MODELMDL);
      # "data array1" holds the number of elements of "data array4"
      read(MODELMDL, $buffer, $ref->{$node}{$structs{'darray'}[1]{'name'}}{'unpacked'}[0] * $structs{'darray'}[4]{'size'});
      print(" " . (tell(MODELMDL)-1) . "\n") if $printall;
      $ref->{$node}{$structs{'darray'}[4]{'name'}}{'end'} = tell(MODELMDL)-1;
      $ref->{$node}{$structs{'darray'}[4]{'name'}}{'raw'} = $buffer;
      $ref->{$node}{$structs{'darray'}[4]{'name'}}{'unpacked'} = [unpack($structs{'darray'}[4]{'tmplt'}, $buffer)];
    }

   #if this is an AABB node read in the AABB tree
   if($nodetype & NODE_HAS_AABB ) {
      #$temp = $ref->{$node}{'subhead'}{'unpacked'}[$structs{'darray'}[10]{'loc'} + $temp2] + 12;
      $temp = $ref->{$node}{'aabbloc'} + 12;
      seek(MODELMDL, $temp, 0);
      print("$tree-$ref->{$node}{'header'}{'unpacked'}[NODEINDEX]_$structs{'darray'}[10]{'name'} " . tell(MODELMDL)) if $printall;
      $ref->{$node}{$structs{'darray'}[10]{'name'}}{'start'} = tell(MODELMDL);

      $ref->{$node}{ $structs{'darray'}[10]{'name'} }{'raw'} = "";
      
      $temp = readaabb($ref, $node, $temp);
      
      $ref->{$node}{$structs{'darray'}[10]{'name'}}{'unpacked'} = [unpack($structs{'darray'}[10]{'tmplt'} x $temp, $ref->{$node}{ $structs{'darray'}[10]{'name'} }{'raw'})];
      
      print(" " . (tell(MODELMDL)-1) . "\n") if $printall;
      $ref->{$node}{$structs{'darray'}[10]{'name'}}{'end'} = tell(MODELMDL)-1;

      $temp--;
      
      $ref->{$node}{'aabbnodes'} = [];
      foreach(0..$temp) {
        $ref->{$node}{'aabbnodes'}[$_] = [];
        $ref->{$node}{'aabbnodes'}[$_][0] = $ref->{$node}{$structs{'darray'}[10]{'name'}}{'unpacked'}[($_ * 10)];
        $ref->{$node}{'aabbnodes'}[$_][1] = $ref->{$node}{$structs{'darray'}[10]{'name'}}{'unpacked'}[($_ * 10) + 1];
        $ref->{$node}{'aabbnodes'}[$_][2] = $ref->{$node}{$structs{'darray'}[10]{'name'}}{'unpacked'}[($_ * 10) + 2];
        $ref->{$node}{'aabbnodes'}[$_][3] = $ref->{$node}{$structs{'darray'}[10]{'name'}}{'unpacked'}[($_ * 10) + 3];
        $ref->{$node}{'aabbnodes'}[$_][4] = $ref->{$node}{$structs{'darray'}[10]{'name'}}{'unpacked'}[($_ * 10) + 4];
        $ref->{$node}{'aabbnodes'}[$_][5] = $ref->{$node}{$structs{'darray'}[10]{'name'}}{'unpacked'}[($_ * 10) + 5];
        $ref->{$node}{'aabbnodes'}[$_][6] = $ref->{$node}{$structs{'darray'}[10]{'name'}}{'unpacked'}[($_ * 10) + 8];
      }
   }

   
   #prepare the faces list
   for (my $i = 0; $i < $ref->{$node}{'facesnum'}; $i++) {
      $temp = ($i * 11);
      $ref->{$node}{'Afaces'}[$i] = $ref->{$node}{$structs{'darray'}[0]{'name'}}{'unpacked'}[$temp + 8];
      $ref->{$node}{'Afaces'}[$i] .=" ".$ref->{$node}{$structs{'darray'}[0]{'name'}}{'unpacked'}[$temp + 9];
      $ref->{$node}{'Afaces'}[$i] .=" ".$ref->{$node}{$structs{'darray'}[0]{'name'}}{'unpacked'}[$temp + 10];
      # some models have non-bitflag-compatible smoothgroup numbers.
      # the theory w/ bitflag smooth-group numbers is that there can only be 32 max.
      # in p_bastilba in k1, there are smooth-groups numbered 251 ... an FF byte missing the 4 bit
      # of course, the vanilla models don't use bitfields in the first place so this is done for nwmax?
      # for now, just passing through sg numbers that are gt 32, also a commented technique to force it into 32 range
      $ref->{$node}{'Afaces'}[$i] .= sprintf(
        " %u", $ref->{$node}{$structs{'darray'}[0]{'name'}}{'unpacked'}[$temp + 4] < 33
                 ? 2**($ref->{$node}{$structs{'darray'}[0]{'name'}}{'unpacked'}[$temp + 4] - 1)
                 : $ref->{$node}{$structs{'darray'}[0]{'name'}}{'unpacked'}[$temp + 4]
                 #: 2**(($ref->{$node}{$structs{'darray'}[0]{'name'}}{'unpacked'}[$temp + 4] % 32) - 1)
      );
      #$ref->{$node}{'Afaces'}[$i] .=" 1";
      $ref->{$node}{'Afaces'}[$i] .=" ".$ref->{$node}{$structs{'darray'}[0]{'name'}}{'unpacked'}[$temp + 8];
      $ref->{$node}{'Afaces'}[$i] .=" ".$ref->{$node}{$structs{'darray'}[0]{'name'}}{'unpacked'}[$temp + 9];
      $ref->{$node}{'Afaces'}[$i] .=" ".$ref->{$node}{$structs{'darray'}[0]{'name'}}{'unpacked'}[$temp + 10];
      if ($nodetype & NODE_HAS_AABB) {
        # surface/material ID is important/meaningful for AABB nodes
        $ref->{$node}{'Afaces'}[$i] .= sprintf(' %u', $ref->{$node}{$structs{'darray'}[0]{'name'}}{'unpacked'}[$temp + 4]);
      } else {
        # otherwise, use material "1", which will get the selected texture(s)
        $ref->{$node}{'Afaces'}[$i] .=" 1";
      }
      #$ref->{$node}{'Afaces'}[$i] .=" ".$ref->{$node}{$structs{'darray'}[0]{'name'}}{'unpacked'}[$temp + 4];
      $ref->{$node}{'Bfaces'}[$i] = [@{$ref->{$node}{$structs{'darray'}[0]{'name'}}{'unpacked'}}[$temp..$temp+10]];
    }
  }

  # if we have nodetype 97 (skin mesh node) cook the bone map stored in data array 5
  if ($nodetype & NODE_HAS_SKIN) {
    $temp = $ref->{$node}{'subhead'}{'unpacked'}[$structs{'darray'}[5]{'num'} + $uoffset];
    for (my $i = 0; $i < $temp; $i++) {
      $ref->{$node}{'node2index'}[$i] = $ref->{$node}{'bonemap'}{'unpacked'}[$i];
      if ($ref->{$node}{'node2index'}[$i] != -1) {
        $ref->{$node}{'index2node'}[ $ref->{$node}{'bonemap'}{'unpacked'}[$i] ] = $i;
      }
    }
  }

  # if this mesh has tangent space data in the MDX, then the texture is supposed to be bump-mapped,
  # record that fact at the model level
  if ($ref->{$node}{'mdxdatabitmap'} & MDX_TANGENT_SPACE) {
    $model->{'bumpmapped_texture'}{lc $ref->{$node}{'bitmap'}} = 1;
  }

  #if we have a non-saber mesh node then we have MDX data to read in
  if ( ($nodetype & NODE_HAS_MESH) && !($nodetype & NODE_HAS_SABER) && ($ref->{$node}{'vertcoordnum'} > 0) ) {
    $ref->{$node}{'verts'} = [];
    #we will be reading from the MDX, so no need to add 12 to addresses
    seek(MODELMDX, $ref->{$node}{'MDXdataloc'}, 0);
    print("mdx-$tree-$ref->{$node}{'header'}{'unpacked'}[NODEINDEX]_$structs{'mdxdata'}{$nodetype}{'name'} " . tell(MODELMDX)) if $printall;
    $ref->{$node}{'mdxdata'}{'start'} = tell(MODELMDX);
    $ref->{$node}{'mdxdata'}{'dnum'} = $ref->{$node}{'mdxdatasize'}/4;
    # the replacer method is actually sensitive to MDX data being fully read,
    # including all padding. it seems like MDX data is 32-byte aligned, enforce it.
    # use 32 % size or size % 32 depending on whether size is less than 32
    # examples: 32 % 24 = 8 (correct) & 64 % 32 = 0 (correct)
    my $alignment_padding = (
      ($ref->{$node}{'mdxdatasize'} < 32 ? 32 : $ref->{$node}{'mdxdatasize'}) %
      ($ref->{$node}{'mdxdatasize'} < 32 ? $ref->{$node}{'mdxdatasize'} : 32)
    );
    read(MODELMDX, $buffer, ($ref->{$node}{'mdxdatasize'} * ($ref->{$node}{'vertcoordnum'} + 1)) + $alignment_padding);
    printf(" %u (%u align pad)\n", (tell(MODELMDX) - 1), $alignment_padding) if $printall;
    $ref->{$node}{'mdxdata'}{'end'} = tell(MODELMDX)-1;
    $ref->{$node}{'mdxdata'}{'raw'} = $buffer;
    #$ref->{$node}{'mdxdata'}{'unpacked'} = [unpack($structs{'mdxdata'}{$nodetype}{'tmplt'}, $buffer)];
    $ref->{$node}{'mdxdata'}{'unpacked'} = [unpack("f*", $buffer)];

    $temp = $ref->{$node}{'mdxdatasize'}/4;  # divide by 4 cuz the data is unpacked
    for (my $i = 0; $i < $ref->{$node}{'vertcoordnum'}; $i++) {
      ### NEW APPROACH TO READING MDX:
      my $row_index = $i * $temp;
      my $row_offset = 0;
      # go through all the types of MDX data
      #XXX we could copy & filter the MDX struct for each node before entering row loop
      for my $mdx_data_type (@{$structs{'mdxrows'}}) {
        if (!($ref->{$node}{'mdxdatabitmap'} & $mdx_data_type->{bitfield}) ||
            !defined($ref->{$node}{$mdx_data_type->{offset}}) ||
            $ref->{$node}{$mdx_data_type->{offset}} == -1) {
          # this type of data is not present in the MDX row
          next;
        }
        # convert from number of bytes to unpacked array index offset
        $row_offset = $ref->{$node}{$mdx_data_type->{offset}} / 4;
        # read the number of values from the row into the specified node data field
        for my $datum_index (0..$mdx_data_type->{num} - 1) {
          $ref->{$node}{$mdx_data_type->{data}}[$i][$datum_index] = $ref->{$node}{'mdxdata'}{'unpacked'}[$row_index + $row_offset + $datum_index];
        }
        # the following is too verbose even for normal verbose
        #print "read mdx $mdx_data_type->{offset} vert $i\n" if $printall;
      } # for $mdx_data_type

      ### MDX DATA POST-PROCESSING
      # if this is a skin node, cook the weights for this vertex
      if ($nodetype & NODE_HAS_SKIN) {
        # construct text representation of bone weights map
        $ref->{$node}{'Abones'}[$i] = '';
        for my $weight_num (0..3) {
          if ($ref->{$node}{'boneweights'}[$i][$weight_num] == 0 ||
              $ref->{$node}{'boneindices'}[$i][$weight_num] == -1) {
            # skip 0 value weights and -1 bone indices
            # in the ASCII bone weight construction
            next;
          }
          my $bone_name = $model->{'partnames'}[
            $ref->{$node}{'index2node'}[$ref->{$node}{'boneindices'}[$i][$weight_num]]
          ];
          $ref->{$node}{'Abones'}[$i] .= sprintf('%s %.7g ', $bone_name, $ref->{$node}{'boneweights'}[$i][$weight_num]);
        }
        # clean off the superfluous trailing space character
        $ref->{$node}{'Abones'}[$i] =~ s/\s+$//;
        # construct binary representation of bone weights map
        $ref->{$node}{'Bbones'}[$i] = [ @{$ref->{$node}{'boneweights'}[$i]},
                                        @{$ref->{$node}{'boneindices'}[$i]} ];
      }
      # if this is a dangly node, cook the constraints for this vertex
      # NOTE: this is here for historical reasons, and isn't even MDX data...
      # according to the original situation of the code,
      # it should only run on textured danglymesh?
      if ($nodetype & NODE_HAS_DANGLY) {
        $ref->{$node}{'constraints'}[$i] = $ref->{$node}{$structs{'darray'}[9]{'name'}}{'unpacked'}[$i];
      }
    } # for $i
  } # if 33 or 97 or 289 or 545
  
  if ($nodetype & NODE_HAS_SABER) {
    $temp = $ref->{$node}{'subhead'}{'unpacked'}[$structs{'data'}{$nodetype}[0]{'num'}];
    for (my $i = 0; $i < $temp; $i++) {
      $ref->{$node}{'verts'}[$i][0] = $ref->{$node}{'vertcoords'}{'unpacked'}[($i * 3) + 0];
      $ref->{$node}{'verts'}[$i][1] = $ref->{$node}{'vertcoords'}{'unpacked'}[($i * 3) + 1];
      $ref->{$node}{'verts'}[$i][2] = $ref->{$node}{'vertcoords'}{'unpacked'}[($i * 3) + 2];
      if ($ref->{$node}{'texturenum'} != 0) {
        $ref->{$node}{'tverts'}[$i][0] = $ref->{$node}{'tverts+'}{'unpacked'}[($i * 2) + 0];
        $ref->{$node}{'tverts'}[$i][1] = $ref->{$node}{'tverts+'}{'unpacked'}[($i * 2) + 1];
      }
      $ref->{$node}{'verts1'}[$i][0] = $ref->{$node}{'vertcoords2'}{'unpacked'}[($i * 3) + 0];
      $ref->{$node}{'verts1'}[$i][1] = $ref->{$node}{'vertcoords2'}{'unpacked'}[($i * 3) + 1];
      $ref->{$node}{'verts1'}[$i][2] = $ref->{$node}{'vertcoords2'}{'unpacked'}[($i * 3) + 2];
      $ref->{$node}{'tverts1offset'}[$i][0] = $ref->{$node}{'data2081-3'}{'unpacked'}[($i * 3) + 0];
      $ref->{$node}{'tverts1offset'}[$i][1] = $ref->{$node}{'data2081-3'}{'unpacked'}[($i * 3) + 1];
      $ref->{$node}{'tverts1offset'}[$i][2] = $ref->{$node}{'data2081-3'}{'unpacked'}[($i * 3) + 2];
    }
  } # if 2081

  
  #if this node has any children then we call this function again
  $numchildren = $ref->{$node}{'childcount'};
  if ($numchildren != 0) {
    $temp = $ref->{$node}{'childrenloc'} + 12;
    seek(MODELMDL, $temp, 0);
    $ref->{$node}{'childindexes'}{'start'} = tell(MODELMDL);
    if ($tree =~ /^anims/) {
      $model->{'nodesort'}{$animnum}{tell(MODELMDL)} = $node . "-childindexes";
    }
    read(MODELMDL, $buffer, $numchildren * 4);
    $ref->{$node}{'childindexes'}{'end'} = tell(MODELMDL)-1;
    @children = unpack("l[$numchildren]", $buffer);
    $ref->{$node}{'childindexes'}{'raw'} = $buffer;
    $ref->{$node}{'childindexes'}{'unpacked'} = [@children];
    # a list of childindex nodenums, rather than byte offsets
    $ref->{$node}{'childindexes'}{'nums'} = [];
    $temp = $model->{'partnames'}[$node];
    foreach (@children) {
      $work = $work + getnodes($tree, $temp, $_, $model, $version) ;
    }    
  }
  return $work;
}

#########################################################
# get a list of the nodes in the order they should be encountered,
# this means traversing the node tree to produce a flattened list.
# recursive, called by writeasciimdl
#
sub getnodelist {
  my ($model, $node_num) = (@_);
  # nodes is the list of node numbers, indexes into model->{nodes},
  # initialize it with the number of current/starting node
  my $nodes = [ $node_num ];
  # hold a convenient reference to the current/starting node
  my $node = $model->{'nodes'}{$node_num};

  if ($node->{'childcount'} && scalar(@{$node->{'childindexes'}{'nums'}})) {
    foreach (@{$node->{'childindexes'}{'nums'}}) {
      # append child node numbers list, recursing
      $nodes = [ @{$nodes}, @{getnodelist($model, $_)} ];
    }
  }

  return $nodes;
}


#########################################################
# write out a model in ascii format
# 
sub writeasciimdl {
  my ($model, $convertskin, $extractanims, $options) = (@_);
  my ($file, $filepath, $node);
  my ($argh1, $argh2, $argh3, $argh4);
  my ($nodetype, $temp, $temp2, %bitmaps);
  my ($controller, $controllername, @args);

  # handle options, fill in default values
  if (!defined($options)) {
    $options = {};
  }
  # convert skin nodes to trimesh
  if (!defined($options->{convert_skin})) {
    #$options->{convert_skin} = 0;
    # once the UI is updated, remove legacy params
    $options->{convert_skin} = $convertskin;
  }
  # write animations in ascii model
  if (!defined($options->{extract_anims})) {
    #$options->{extract_anims} = 1;
    # once the UI is updated, remove legacy params
    $options->{extract_anims} = $extractanims;
  }
  # convert bezier animation controllers to linear
  if (!defined($options->{convert_bezier})) {
    $options->{convert_bezier} = 0;
  }

  $file = $model->{'filename'};
  $filepath = $model->{'filepath+name'};
  
  open(MODELOUT, ">", $filepath."-ascii.mdl") or die "can't open out file\n";
  
  # write out the ascii mdl
  #write out the model header
  print(MODELOUT "# mdlops ver: $VERSION from KOTOR $model->{'source'} source\n");
  print(MODELOUT "# model $model->{'partnames'}[0]\n");
  print(MODELOUT "filedependancy $file NULL.mlk\n");
  print(MODELOUT "newmodel $model->{'partnames'}[0]\n");
  print(MODELOUT "setsupermodel $model->{'partnames'}[0] $model->{'supermodel'}\n");
  print(MODELOUT "classification $model->{'classification'}\n");
  print(MODELOUT "setanimationscale $model->{'animationscale'}\n\n");
  
  # track bumpmapped textures at the model level,
  # this will need to be tested against client software like nwmax
  # this is our only way to know whether a mesh requires tangent space calculations
  if (defined($model->{'bumpmapped_texture'}) &&
      scalar(keys %{$model->{'bumpmapped_texture'}})) {
      foreach (keys %{$model->{'bumpmapped_texture'}}) {
          printf(MODELOUT "bumpmapped_texture %s\n", $_);
      }
      print(MODELOUT "\n");
  }

  print(MODELOUT "beginmodelgeom $model->{'partnames'}[0]\n");
  print(MODELOUT "  bmin $model->{'bmin'}[0] $model->{'bmin'}[1] $model->{'bmin'}[2]\n");
  print(MODELOUT "  bmax $model->{'bmax'}[0] $model->{'bmax'}[1] $model->{'bmax'}[2]\n");
  print(MODELOUT "  radius $model->{'radius'}\n");

  #write out the nodes
  for my $i (@{getnodelist($model, 0)}) {
    print("Node: " . $i . "\n") if $printall;
    $nodetype = $model->{'nodes'}{$i}{'nodetype'};
    $temp = $model->{'partnames'}[$i];
    if ($nodetype == NODE_DUMMY) {
      $temp2 = "dummy";
    } elsif ($nodetype == NODE_LIGHT) {
      $temp2 = "light";
    } elsif ($nodetype == NODE_EMITTER) {
      $temp2 = "emitter";
    } elsif ($nodetype == NODE_DANGLYMESH) {
      $temp2 = "danglymesh";
    } elsif ($nodetype == NODE_SKIN && !$options->{convert_skin}) {
      $temp2 = "skin";
    } elsif ($nodetype == NODE_SKIN && $options->{convert_skin}) {
      $temp2 = "trimesh";
    } elsif ($nodetype == NODE_TRIMESH) {
      $temp2 = "trimesh";
    } elsif ($nodetype == NODE_AABB) {
      $temp2 = "aabb";
    } elsif ($nodetype == NODE_SABER) {
#      $temp2 = "dummy";
      $temp2 = "trimesh";
    } else {
      $temp2 = "dummy";
    }

    if ( $nodetype == NODE_SABER ) {
      print(MODELOUT "node " . $temp2 . " 2081__" . $temp . "\n");
    } else {
      print(MODELOUT "node " . $temp2 . " " . $temp . "\n");
    }
    print(MODELOUT "  parent " . $model->{'nodes'}{$i}{'parent'} . "\n");

    print(MODELHINT "$temp,$model->{'nodes'}{$i}{'supernode'}\n");

    # cleanup Acontrollers XXX move this sometime...
    # remove leading and trailing space from all Acontroller 0 entries
    # so that they split correctly
    foreach(keys %{$model->{'nodes'}{$i}{'Acontrollers'}}) {
        # continue if the length of this acontroller array is 0, aka empty
        if (!scalar(@{$model->{'nodes'}{$i}{'Acontrollers'}{$_}})) {
            next;
        }
        $model->{'nodes'}{$i}{'Acontrollers'}{$_}[0] =~ s/^\s+//;
        $model->{'nodes'}{$i}{'Acontrollers'}{$_}[0] =~ s/\s+$//;
    }

    # general controller types
    # position
    (undef, $argh1, $argh2, $argh3) = split(/\s+/,$model->{'nodes'}{$i}{'Acontrollers'}{8}[0]);
    if ($argh1 ne "") {
      printf(MODELOUT "  position % .7g % .7g % .7g\n", $argh1, $argh2, $argh3);
    }
    # orientation
    (undef, $argh1, $argh2, $argh3, $argh4) = split(/\s+/,$model->{'nodes'}{$i}{'Acontrollers'}{20}[0]);
    if ($argh1 ne "") {
      printf(MODELOUT "  orientation % .7g % .7g % .7g % .7g\n", $argh1, $argh2, $argh3, $argh4);
    }
    # scale
    (undef, $argh1) = split(/\s+/,$model->{'nodes'}{$i}{'Acontrollers'}{36}[0]);
    if ($argh1 ne "") {
      printf(MODELOUT "  scale % .7g\n", $argh1);
    }
    
    # alpha i.e. "see through" - controller number overlaps with an emitter controller number.
    if (!($nodetype & NODE_HAS_EMITTER)) {
      (undef, $argh1) = split(/\s+/,$model->{'nodes'}{$i}{'Acontrollers'}{132}[0]);
      if ($argh1 ne "") {
        printf(MODELOUT "  alpha % .7g\n", $argh1);
      }
    }
    
    # mesh node controller types
    if ($nodetype & NODE_HAS_MESH) {
      # self illumination i.e. "glow"    
      (undef, $argh1, $argh2, $argh3) = split(/\s+/,$model->{'nodes'}{$i}{'Acontrollers'}{100}[0]);
      if ($argh1 ne "" && $argh2 ne "") {
        printf(MODELOUT "  selfillumcolor %.7g %.7g %.7g\n", $argh1, $argh2, $argh3);
      }
    }
    
    # diffuse color    
    if ( defined($model->{'nodes'}{$i}{'diffuse'}[0]) ) {
      printf(MODELOUT "  diffuse %.7g %.7g %.7g\n", @{$model->{'nodes'}{$i}{'diffuse'}});
    }
    
    # not light node type
    #if (!($nodetype & NODE_HAS_LIGHT)) {
    # the parts of the following that actually exist are in mesh header
    if ($nodetype & NODE_HAS_MESH) {
      # ambient color    
      if ( defined($model->{'nodes'}{$i}{'ambient'}[0]) ) {
        printf(MODELOUT "  ambient %.7g %.7g %.7g\n", @{$model->{'nodes'}{$i}{'ambient'}});
      }
      # render flag    
      if ( defined($model->{'nodes'}{$i}{'render'}) ) {
        printf(MODELOUT "  render %u\n", $model->{'nodes'}{$i}{'render'});
      }
      # shadow flag    
      if ( defined($model->{'nodes'}{$i}{'shadow'}) ) {
        printf(MODELOUT "  shadow %u\n", $model->{'nodes'}{$i}{'shadow'});
      }
      print(MODELOUT "  specular 0.000000 0.000000 0.000000\n");
      print(MODELOUT "  shininess 0.000000\n");
      print(MODELOUT "  wirecolor 1 1 1\n");
    }
     
    # light node
    if ( $nodetype == NODE_LIGHT ) {
      # subheader data
      print(MODELOUT "  ambientonly " . $model->{'nodes'}{$i}{'ambientonly'} . "\n");
      print(MODELOUT "  nDynamicType " . $model->{'nodes'}{$i}{'ndynamictype'} . "\n"); #should possibly be isDynamic, but this is what nwmax outputs
      print(MODELOUT "  affectDynamic " . $model->{'nodes'}{$i}{'affectdynamic'} . "\n");
      print(MODELOUT "  shadow " . $model->{'nodes'}{$i}{'shadow'} . "\n");
      print(MODELOUT "  flare " . $model->{'nodes'}{$i}{'flare'} . "\n");
      print(MODELOUT "  lightpriority " . $model->{'nodes'}{$i}{'lightpriority'} . "\n");
      print(MODELOUT "  fadingLight " . $model->{'nodes'}{$i}{'fadinglight'} . "\n");

      my $has_flares = defined($model->{'nodes'}{$i}{'flarepositions'}) &&
                       scalar(@{$model->{'nodes'}{$i}{'flarepositions'}});

      # lens flare properties implementation
      if ($has_flares) {
        # not really planning to use this, but this is how neverblender outputs it ... nwmax?
        printf(MODELOUT "  lensflares %u\n", scalar(@{$model->{'nodes'}{$i}{'flarepositions'}}));
      }
      if ($has_flares && scalar(@{$model->{'nodes'}{$i}{'texturenames'}})) {
        printf(MODELOUT "  texturenames %u\n    %s\n",
               scalar(@{$model->{'nodes'}{$i}{'texturenames'}}),
               join("\n    ", @{$model->{'nodes'}{$i}{'texturenames'}}));
      }
      if ($has_flares && scalar(@{$model->{'nodes'}{$i}{'flarepositions'}})) {
        printf(MODELOUT "  flarepositions %u\n    %s\n",
               scalar(@{$model->{'nodes'}{$i}{'flarepositions'}}),
               join("\n    ", map { sprintf('% .7g', $_); } @{$model->{'nodes'}{$i}{'flarepositions'}}));
      }
      if ($has_flares && scalar(@{$model->{'nodes'}{$i}{'flaresizes'}})) {
        printf(MODELOUT "  flaresizes %u\n    %s\n",
               scalar(@{$model->{'nodes'}{$i}{'flaresizes'}}),
               join("\n    ", map { sprintf('%.7g', $_); } @{$model->{'nodes'}{$i}{'flaresizes'}}));
      }
      if ($has_flares && scalar(@{$model->{'nodes'}{$i}{'flarecolorshifts'}})) {
        printf(MODELOUT "  flarecolorshifts %u\n",
               scalar(@{$model->{'nodes'}{$i}{'flarecolorshifts'}}));
        for my $shift_col (@{$model->{'nodes'}{$i}{'flarecolorshifts'}}) {
          printf(MODELOUT "    %.7g %.7g %.7g\n", @{$shift_col});
        }
      }
      printf(MODELOUT "  flareradius %.7g\n", $model->{'nodes'}{$i}{'flareradius'});

      # controllers
      while(($controller, $controllername) = each %{$controllernames{+NODE_HAS_LIGHT}}) {
        (undef, @args) = split(/\s+/,$model->{'nodes'}{$i}{'Acontrollers'}{$controller}[0]);
        if ($args[0] ne "") {
          printf(MODELOUT "  %s %s\n", $controllername, join(" ", @args));
        }
      }
    }
    
    # emitter node
    if ( $nodetype == NODE_EMITTER ) {
      # subheader data
      print(MODELOUT "  deadspace " . $model->{'nodes'}{$i}{'deadspace'} . "\n");
      print(MODELOUT "  blastRadius " . $model->{'nodes'}{$i}{'blastRadius'} . "\n");
      print(MODELOUT "  blastLength " . $model->{'nodes'}{$i}{'blastLength'} . "\n");
      print(MODELOUT "  numBranches " . $model->{'nodes'}{$i}{'numBranches'} . "\n");
      print(MODELOUT "  controlptsmoothing " . $model->{'nodes'}{$i}{'controlptsmoothing'} . "\n");
      print(MODELOUT "  xgrid " . $model->{'nodes'}{$i}{'xgrid'} . "\n");
      print(MODELOUT "  ygrid " . $model->{'nodes'}{$i}{'ygrid'} . "\n");
      print(MODELOUT "  spawntype " . $model->{'nodes'}{$i}{'spawntype'} . "\n");
      print(MODELOUT "  update " . $model->{'nodes'}{$i}{'update'} . "\n");
      print(MODELOUT "  render " . $model->{'nodes'}{$i}{'render'} . "\n");
      print(MODELOUT "  blend " . $model->{'nodes'}{$i}{'blend'} . "\n");
      print(MODELOUT "  texture " . $model->{'nodes'}{$i}{'texture'} . "\n");
      if ($model->{'nodes'}{$i}{'chunkname'} ne "") {
        print(MODELOUT "  chunkname " . $model->{'nodes'}{$i}{'chunkname'} . "\n");
      }
      print(MODELOUT "  twosidedtex " . $model->{'nodes'}{$i}{'twosidedtex'} . "\n");
      print(MODELOUT "  loop " . $model->{'nodes'}{$i}{'loop'} . "\n");
      print(MODELOUT "  m_bFrameBlending " . $model->{'nodes'}{$i}{'m_bFrameBlending'} . "\n");
      print(MODELOUT "  m_sDepthTextureName " . $model->{'nodes'}{$i}{'m_sDepthTextureName'} . "\n");

      printf(MODELOUT "\n# DEBUG MODE:\n  m_bUnknown1 %u\nm_lUnknown2 %u\n\n",
                      $model->{'nodes'}{$i}{'m_bUnknown1'}, $model->{'nodes'}{$i}{'m_lUnknown2'});

      print(MODELOUT "  p2p " . $model->{'nodes'}{$i}{'p2p'} . "\n");
      print(MODELOUT "  p2p_sel " . $model->{'nodes'}{$i}{'p2p_sel'} . "\n");
      print(MODELOUT "  affectedByWind " . $model->{'nodes'}{$i}{'affectedByWind'} . "\n");
      print(MODELOUT "  m_isTinted " . $model->{'nodes'}{$i}{'m_isTinted'} . "\n");
      print(MODELOUT "  bounce " . $model->{'nodes'}{$i}{'bounce'} . "\n");
      print(MODELOUT "  random " . $model->{'nodes'}{$i}{'random'} . "\n");
      print(MODELOUT "  inherit " . $model->{'nodes'}{$i}{'inherit'} . "\n");
      print(MODELOUT "  inheritvel " . $model->{'nodes'}{$i}{'inheritvel'} . "\n");
      print(MODELOUT "  inherit_local " . $model->{'nodes'}{$i}{'inherit_local'} . "\n");
      print(MODELOUT "  splat " . $model->{'nodes'}{$i}{'splat'} . "\n");
      print(MODELOUT "  inherit_part " . $model->{'nodes'}{$i}{'inherit_part'} . "\n");
      print(MODELOUT "  depth_texture " . $model->{'nodes'}{$i}{'depth_texture'} . "\n");
      print(MODELOUT "  renderorder " . $model->{'nodes'}{$i}{'renderorder'} . "\n");
    
      # controllers
      while(($controller, $controllername) = each %{$controllernames{+NODE_HAS_EMITTER}}) {
        (undef, @args) = split(/\s+/,$model->{'nodes'}{$i}{'Acontrollers'}{$controller}[0]);
        if ($args[0] ne "") {
          printf(MODELOUT "  %s %s\n", $controllername, join(" ", @args));
        }
      }
    }
    
    # mesh nodes
    if ( $nodetype == NODE_TRIMESH || $nodetype == NODE_SKIN || $nodetype == NODE_DANGLYMESH || $nodetype == NODE_AABB || $nodetype == NODE_SABER ) {
      printf(MODELOUT "  bmin % .7g % .7g % .7g\n", @{$model->{'nodes'}{$i}{'bboxmin'}}[0..2]);
      printf(MODELOUT "  bmax % .7g % .7g % .7g\n", @{$model->{'nodes'}{$i}{'bboxmax'}}[0..2]);
      printf(MODELOUT "  radius % .7g\n", $model->{'nodes'}{$i}{'radius'});
      printf(MODELOUT "  average % .7g % .7g % .7g\n", @{$model->{'nodes'}{$i}{'average'}}[0..2]);

      # render, shadow, ambient, and diffuse should all be in here, they are not actually general
      printf(MODELOUT "  lightmapped %u\n", $model->{'nodes'}{$i}{'lightmapped'});
      printf(MODELOUT "  rotatetexture %u\n", $model->{'nodes'}{$i}{'rotatetexture'});
      printf(MODELOUT "  m_bIsBackgroundGeometry %u\n", $model->{'nodes'}{$i}{'m_bIsBackgroundGeometry'});
      printf(MODELOUT "  beaming %u\n", $model->{'nodes'}{$i}{'beaming'});
      printf(MODELOUT "  transparencyhint %u\n", $model->{'nodes'}{$i}{'transparencyhint'});

      # test for presence of k2 specific flags
      if (defined($model->{'nodes'}{$i}{'dirt_enabled'})) {
          printf(MODELOUT "  dirt_enabled %u\n", $model->{'nodes'}{$i}{'dirt_enabled'});
          printf(MODELOUT "  dirt_texture %u\n", $model->{'nodes'}{$i}{'dirt_texture'});
          printf(MODELOUT "  dirt_worldspace %u\n", $model->{'nodes'}{$i}{'dirt_worldspace'});
          printf(MODELOUT "  hologram_donotdraw %u\n", $model->{'nodes'}{$i}{'hologram_donotdraw'});
      }

      # this is the property magnusII classified as 'shininess'
      # my current understanding is that this is actually animated uv maps,
      # used, for example, to show the 'current' of a river, or a moving cloud,
      # that is the theory, definitely unconfirmed at this time
      printf(MODELOUT "  animateuv %u\n", $model->{'nodes'}{$i}{'animateuv'});
      printf(MODELOUT "  uvdirectionx % .7g\n", $model->{'nodes'}{$i}{'uvdirectionx'});
      printf(MODELOUT "  uvdirectiony % .7g\n", $model->{'nodes'}{$i}{'uvdirectiony'});
      printf(MODELOUT "  uvjitter % .7g\n", $model->{'nodes'}{$i}{'uvjitter'});
      printf(MODELOUT "  uvjitterspeed % .7g\n", $model->{'nodes'}{$i}{'uvjitterspeed'});

      printf(MODELOUT "  bitmap %s\n", $model->{'nodes'}{$i}{'bitmap'});
      if (length($model->{'nodes'}{$i}{'bitmap2'})) {
          printf(MODELOUT "  bitmap2 %s\n", $model->{'nodes'}{$i}{'bitmap2'});
      }
      if (length($model->{'nodes'}{$i}{'texture0'})) {
          printf(MODELOUT "  texture0 %s\n", $model->{'nodes'}{$i}{'texture0'});
      }
      if (length($model->{'nodes'}{$i}{'texture1'})) {
          printf(MODELOUT "  texture1 %s\n", $model->{'nodes'}{$i}{'texture1'});
      }
      $bitmaps{ lc($model->{'nodes'}{$i}{'bitmap'}) } += 1;
      printf(MODELOUT "  verts %u\n", $model->{'nodes'}{$i}{'vertcoordnum'});
      foreach ( @{$model->{'nodes'}{$i}{'verts'}} ) {
        printf(MODELOUT "    % .7g % .7g % .7g\n", @{$_});
      }
      printf(MODELOUT "  faces %u\n", $model->{'nodes'}{$i}{'facesnum'});
      foreach ( @{$model->{'nodes'}{$i}{'Afaces'}} ) {
        print (MODELOUT "    $_\n");
      }
      # properly use the mdx bitmap here
      # there are nodes that contain only slot 2 textures,
      # for example: m12aa_01p in K1
      # saber mesh does not use MDX, so bypass this check if it claims to be textured
      # TODO: repeat this for texture slots 2-4
      if ($model->{'nodes'}{$i}{'texturenum'} != 0 &&
          ($model->{'nodes'}{$i}{'mdxdatabitmap'} & MDX_TEX0_VERTICES ||
           $nodetype & NODE_HAS_SABER)) {
        # write out tverts, nwmax requires these to be 3 coordinate numbers
        printf(MODELOUT "  tverts %u\n", $model->{'nodes'}{$i}{'vertcoordnum'});
        foreach ( @{$model->{'nodes'}{$i}{'tverts'}} ) {
          printf(MODELOUT "    % .7g % .7g 0.0\n", $_->[0], $_->[1]);
        }
      }
      if (length($model->{'nodes'}{$i}{'bitmap2'}) &&
          scalar(@{$model->{'nodes'}{$i}{'tverts1'}})) {
        # write out tverts1, nwmax would require these to be 3 coordinate numbers
        printf(MODELOUT "  tverts1 %u\n", scalar(@{$model->{'nodes'}{$i}{'tverts1'}}));
        foreach ( @{$model->{'nodes'}{$i}{'tverts1'}} ) {
          printf(MODELOUT "    % .7g % .7g 0.0\n", $_->[0], $_->[1]);
        }
      }
      if (length($model->{'nodes'}{$i}{'texture0'}) &&
          scalar(@{$model->{'nodes'}{$i}{'tverts2'}})) {
        # write out tverts2, nwmax would require these to be 3 coordinate numbers
        printf(MODELOUT "  tverts2 %u\n", scalar(@{$model->{'nodes'}{$i}{'tverts2'}}));
        foreach ( @{$model->{'nodes'}{$i}{'tverts2'}} ) {
          printf(MODELOUT "    % .7g % .7g 0.0\n", $_->[0], $_->[1]);
        }
      }
      if (length($model->{'nodes'}{$i}{'texture1'}) &&
          scalar(@{$model->{'nodes'}{$i}{'tverts3'}})) {
        # write out tverts3, nwmax would require these to be 3 coordinate numbers
        printf(MODELOUT "  tverts3 %u\n", scalar(@{$model->{'nodes'}{$i}{'tverts3'}}));
        foreach ( @{$model->{'nodes'}{$i}{'tverts3'}} ) {
          printf(MODELOUT "    % .7g % .7g 0.0\n", $_->[0], $_->[1]);
        }
      }
      if ($nodetype & NODE_HAS_SABER) {
        printf(MODELOUT "  verts1 %u\n", scalar(@{$model->{'nodes'}{$i}{'verts1'}}));
        foreach ( @{$model->{'nodes'}{$i}{'verts1'}} ) {
          printf(MODELOUT "    % .7g % .7g % .7g\n", @{$_});
        }
        printf(MODELOUT "  tverts1offset %u\n", scalar(@{$model->{'nodes'}{$i}{'tverts1offset'}}));
        foreach ( @{$model->{'nodes'}{$i}{'tverts1offset'}} ) {
          printf(MODELOUT "    % .7g % .7g % .7g\n", @{$_});
        }
      }
      if ($nodetype == NODE_SKIN && !$options->{convert_skin}) {
        printf(MODELOUT "  weights %u\n", $model->{'nodes'}{$i}{'vertcoordnum'});
        foreach ( @{$model->{'nodes'}{$i}{'Abones'}} ) {
          printf(MODELOUT "    %s\n", $_);
        }
      }
      if ($nodetype == NODE_DANGLYMESH) {
        printf(MODELOUT "  displacement % .7g\n", $model->{'nodes'}{$i}{'displacement'});
        printf(MODELOUT "  tightness % .7g\n", $model->{'nodes'}{$i}{'tightness'});
        printf(MODELOUT "  period % .7g\n", $model->{'nodes'}{$i}{'period'});
        printf(MODELOUT "  constraints %u\n", $model->{'nodes'}{$i}{'vertcoordnum'});
        foreach ( @{$model->{'nodes'}{$i}{'constraints'}} ) {
          printf(MODELOUT "    % .7g\n", $_);
        }
      }
      if ($nodetype == NODE_AABB) {
        #print (MODELOUT "  aabb\n");
        # i read somewhere that nwmax crashes if aabb does not start on same line...
        print (MODELOUT "  aabb");
        foreach ( @{$model->{'nodes'}{$i}{'aabbnodes'}} ) {
          printf(MODELOUT "      % .7g % .7g % .7g % .7g % .7g % .7g %d\n", @{$_}[0..6]);
        }
      }
    }
    print (MODELOUT "endnode\n");
  }
  printf(MODELOUT "endmodelgeom %s\n", $model->{'partnames'}[0]);

    
  # write out the animations if there are any and we are told to do so
  if ($model->{'numanims'} != 0 && $options->{extract_anims}) {
    # loop through the animations
    for (my $i = 0; $i < $model->{'numanims'}; $i++) {
      printf(MODELOUT "\nnewanim %s %s\n", $model->{'anims'}{$i}{'name'}, $model->{'partnames'}[0]);
      printf(MODELOUT "  length %.7g\n", $model->{'anims'}{$i}{'length'});
      printf(MODELOUT "  transtime %.7g\n", $model->{'anims'}{$i}{'transtime'});
      printf(MODELOUT "  animroot %s\n", $model->{'anims'}{$i}{'animroot'});
      if ($model->{'anims'}{$i}{'eventsnum'} != 0) {
        #print(MODELOUT "  eventlist\n");
        foreach ( @{$model->{'anims'}{$i}{'animevents'}{'ascii'}} ) {
          #printf(MODELOUT "    %s\n", $_);
          printf(MODELOUT "  event %s\n", $_);
        }
        #print(MODELOUT "  endlist\n");
      }
      # loop through this animations nodes
      foreach $node (sort {$a <=> $b} keys(%{$model->{'anims'}{$i}{'nodes'}}) ) {
        if ($node eq "truenodenum") {next;}
        print(MODELOUT "  node dummy $model->{'partnames'}[$node]\n");
        print(MODELOUT "    parent $model->{'anims'}{$i}{'nodes'}{$node}{'parent'}\n");

        # loop though this animations controllers
        foreach $temp (keys %{$model->{'anims'}{$i}{'nodes'}{$node}{'Acontrollers'}} ) {
          if ($temp != 42) {
            my $controllername = getcontrollername($model, $temp, $node);

            my $keytype = '';
            if (defined($model->{'anims'}{$i}{'nodes'}{$node}{'controllers'}{'bezier'}{$temp})) {
              $keytype = 'bezier';
            }

            if ($controllername ne "") {
              printf(MODELOUT "    %s%skey\n", $controllername, !$options->{convert_bezier} ? $keytype : '');
            } else {
              if ($temp != 0) {
                print "didn't find controller $temp in node type $model->{'nodes'}{$node}{'nodetype'} \n";
              }
              printf(MODELOUT "    controller%u%skey\n", $temp, $keytype);
            }
            foreach ( @{$model->{'anims'}{$i}{'nodes'}{$node}{'Acontrollers'}{$temp}} ) {
              # convert bezier controller data to linear, not a true conversion,
              # we are just dropping the control points, as has been done historically
              if ($options->{convert_bezier} && $keytype eq 'bezier') {
                # split into an array
                $_ = [ split(/\s+/, $_) ];
                if (scalar(@{$_}) > 8) {
                  # remove last 6 items from array, which are the bezier control points
                  $_ = join(' ', @{$_}[0..scalar(@{$_}) - 7]);
                } else {
                  # malformed data, should have had 1 time, 1+ data, and 6 control point
                  $_ = join(' ', @{$_});
                }
              }
              printf(MODELOUT "      %s\n", $_);
            }
            print(MODELOUT "    endlist\n");
          }
        } # foreach $temp
        print(MODELOUT "  endnode\n");
      } # foreach $node
      
      $temp = $i;
      printf(MODELOUT "\ndoneanim %s %s\n", $model->{'anims'}{$i}{'name'}, $model->{'partnames'}[0]);
    } # for $i
  } # if to do animations
  
  printf(MODELOUT "\ndonemodel %s\n", $model->{'partnames'}[0]);

  close MODELOUT;
}


###########################################################
# Used by writeasciimodel.
# Given a node type and controller number, return the name.
# 
sub getcontrollername {
  my ($model, $controllernum, $node) = (@_);
  my $nodetype = $model->{'nodes'}{$node}{'nodetype'};
  my @nodeheaders = (NODE_HAS_MESH, NODE_HAS_EMITTER, NODE_HAS_LIGHT, NODE_HAS_HEADER);
  
  foreach (@nodeheaders) {
    if (($nodetype & $_) && ($controllernames{$_}{$controllernum} ne '')) {
      return $controllernames{$_}{$controllernum};
    }
  }
  
  return '';
}


#########################################################
# Used by readasciimdl.
# Determine if 2 vectors/vertices are equivalent
# Allows caller to specify precision for matching
# Now safe for comparing any two same-sized numeric lists
#
sub vertex_equals {
  my ($vert1, $vert2, $precision) = @_;

  if (!defined($precision)) {
    $precision = 6;
  }
  my $max_diff = 10 ** (0 - $precision);

  my $size = scalar(@{$vert1});

  my $matches = 0;
  for my $index (0..$size - 1) {
    if ($vert1->[$index] == $vert2->[$index] ||
        abs($vert1->[$index] - $vert2->[$index]) < $max_diff) {
      $matches += 1;
    }
  }
  if ($matches == $size) {
    return 1;
  }

  return 0;
}


#########################################################
# Normalize vector passed in as listref, return normalized listref
#
sub normalize_vector {
  my ($vec) = @_;

  my $norm_vec = [ 1, 0, 0 ];
  my $norm = sqrt($vec->[0]**2 + $vec->[1]**2 + $vec->[2]**2);
  if ($norm) {
    $norm_vec = [ map { $_ / $norm } @{$vec} ];
  }

  return $norm_vec;
}


#########################################################
# Used by readasciimdl.
# compute angle as radians between vectors vec1 and vec2
#
sub compute_vector_angle {
  my ($vec1, $vec2, $normalized) = @_;
  my (@v1, @v2);
  my $angle;

  @v1 = !$normalized ? @{normalize_vector($vec1)} : @{$vec1};
  @v2 = !$normalized ? @{normalize_vector($vec2)} : @{$vec2};

  # angle = acos(v1 dot v2 / |v1||v2|)
  my $dot_product = $v1[0] * $v2[0] + $v1[1] * $v2[1] + $v1[2] * $v2[2];
  # v1 and v2 are normalized, so angle = acos(v1 dot v2)
  #$angle = acos(
  #  ($v1[0] * $v2[0] + $v1[1] * $v2[1] + $v1[2] * $v2[2]) /
  #  (sqrt($v1[0]**2 + $v1[1]**2 + $v1[2]**2) *
  #   sqrt($v2[0]**2 + $v2[1]**2 + $v2[2]**2))
  #);
  $angle = acos($dot_product);
  if ($dot_product < 0) {
    # obtuse angle
    $angle = (2 * pi) - $angle;
  } elsif ($dot_product == 0) {
    # same angle, pointing in same direction or opposite?
    if (vertex_equals(\@v1, \@v2)) {
      return 0;
    } else {
      return pi / 2;
    }
  }
  # acute angle
  #print Dumper($angle);
  return $angle;
}


#########################################################
# Used by readasciimdl.
# compute angle as radians between face edges at vertex lp
# uses edges lp <-> rp1 and lp <-> rp2
#
sub compute_vertex_angle {
  my ($lp, $rp1, $rp2) = @_;
  my (@v1, @v2, @v3) = ([0, 0, 0], [0, 0, 0], [0, 0, 0]);
  my $angle;
  # point 1, the local point around which angle is calculated
  my @pt1 = @{$lp};
  # point 2, comparison, the first remote point describing an edge
  my @cpt2 = @{$rp1};
  # point 3, comparison, the second remote point describing an edge
  my @cpt3 = @{$rp2};
#use Data::Dumper;
#print Dumper($lp, $rp1, $rp2);

  $v1[0] = $pt1[0] - $cpt2[0];
  $v1[1] = $pt1[1] - $cpt2[1];
  $v1[2] = $pt1[2] - $cpt2[2];

  $v2[0] = $pt1[0] - $cpt3[0];
  $v2[1] = $pt1[1] - $cpt3[1];
  $v2[2] = $pt1[2] - $cpt3[2];

  return compute_vector_angle(\@v1, \@v2);
}


###########################################################
# Used by readsinglecontroller and readkeyedcontroller.
# Convert angle-axis to quaternion. Outputs as (x,y,z,w).
# 
sub aatoquaternion {
  my ($aaref) = (@_);

  # 2016 updated method to produce closer matching results
  my $sin_a = sin($aaref->[3] / 2);
  if (abs($sin_a) < 0.00005 && $sin_a != 0.0) {
    # only use this for tiny non-zero sin values because it is the most
    # common case: 1 0 0 0
    $sin_a = 1;
  }

  $aaref->[0] = $aaref->[0] * $sin_a;
  $aaref->[1] = $aaref->[1] * $sin_a;
  $aaref->[2] = $aaref->[2] * $sin_a;
  $aaref->[3] = cos($aaref->[3] / 2);
}

###########################################################
# Used by readasciicontroller.
# Parse a single controller (single line of data).
# 
sub readsinglecontroller {
  my ($line, $modelref, $nodenum, $controller, $controllername) = (@_);
  my @controllerdata;
  my $temp;

  if ($line =~ /^\s*$controllername(\s+(\S*))+/i) {
    $line =~ s/\s*$controllername//i;
    @controllerdata = ($line =~ /\s+(\S+)/g);
    $modelref->{'nodes'}{$nodenum}{'controllernum'}++;
    $modelref->{'nodes'}{$nodenum}{'controllerdatanum'} += (scalar(@controllerdata) + 1); # add 1 for the time value
    $modelref->{'nodes'}{$nodenum}{'Acontrollers'}{$controller}[0] = "0 " . join(' ', @controllerdata);
    $modelref->{'nodes'}{$nodenum}{'Bcontrollers'}{$controller}{'rows'} = 1;
    $modelref->{'nodes'}{$nodenum}{'Bcontrollers'}{$controller}{'times'}[0] = 0;
    if ($controller == 20) {
      aatoquaternion(\@controllerdata);
    }
    $modelref->{'nodes'}{$nodenum}{'Bcontrollers'}{$controller}{'values'}[0] = \@controllerdata;
    return 1;
  }
  return 0;
}

###########################################################
# Used by readasciicontroller.
# Parse a keyed controller (multiple lines of data).
# 
sub readkeyedcontroller {
  my ($line, $modelref, $nodenum, $animnum, $ASCIIFILE, $controller, $controllername) = (@_);
  my $count;

  if ($line =~ /^\s*${controllername}(bezier)?key/i) {
    my $total;
    my $bezier = 0;
    if (defined($1) && lc($1) eq 'bezier') {
      $bezier = 1;
      $modelref->{'anims'}{$animnum}{'nodes'}{$nodenum}{'controllers'}{'bezier'}{$controller} = 1;
    }
    if ($line =~ /key\s+(\d+)$/i) {
      # old versions of mdlops did not use endlist, instead had 'positionkey 4' for 4 keyframes
      $total = int $1;
    }
    $modelref->{'anims'}{$animnum}{'nodes'}{$nodenum}{'controllernum'}++;
    $count = 0;
    while ((!$total || $count < $total) && ($line = <$ASCIIFILE>) && $line !~ /endlist/) {
      my @controllerdata = ($line =~ /\s+(\S+)/g); # "my" here makes sure it's a new array each time; without it, earlier values are clobbered
      $modelref->{'anims'}{$animnum}{'nodes'}{$nodenum}{'controllerdatanum'} += scalar(@controllerdata); # time value included already
      $modelref->{'anims'}{$animnum}{'nodes'}{$nodenum}{'Acontrollers'}{$controller}[$count] = join(' ', @controllerdata);
      $modelref->{'anims'}{$animnum}{'nodes'}{$nodenum}{'Bcontrollers'}{$controller}{'rows'}++;
      $modelref->{'anims'}{$animnum}{'nodes'}{$nodenum}{'Bcontrollers'}{$controller}{'times'}[$count] = shift (@controllerdata);
      
      # special cases:
      if ($controller == 20) {
      # orientation: convert to quaternions
        aatoquaternion(\@controllerdata);
      } elsif ($controller == 8) {
      # position: take delta from geometry node
        $controllerdata[0] -= $modelref->{'nodes'}{$nodenum}{'Bcontrollers'}{8}{'values'}[0][0];
        $controllerdata[1] -= $modelref->{'nodes'}{$nodenum}{'Bcontrollers'}{8}{'values'}[0][1];
        $controllerdata[2] -= $modelref->{'nodes'}{$nodenum}{'Bcontrollers'}{8}{'values'}[0][2];
      }
      
      $modelref->{'anims'}{$animnum}{'nodes'}{$nodenum}{'Bcontrollers'}{$controller}{'values'}[$count] = \@controllerdata;
      $count++;
    }
    return 1;
  }

  return 0;  
}


###########################################################
# For use by readasciimodel.
# Parse controller out of the input file.
# 
sub readasciicontroller {
# parsing controllers one at a time was fine when there were 5, but sucks when there are, like, 40.
# hopefully this'll work a bit better and won't have too many special cases.
  my ($line, $nodetype, $innode, $isanimation, $modelref, $nodenum, $animnum, $ASCIIFILE) = (@_);
  my ($controller, $controllername, $nodetype);
  
  $nodetype = $modelref->{'nodes'}{$nodenum}{'nodetype'};
  # go through each of the types that have controllers (last is essentially "any node")
  for my $type_test (NODE_HAS_LIGHT, NODE_HAS_EMITTER, NODE_HAS_MESH, NODE_HAS_HEADER) {
      # if this node has this type
      if ($nodetype & $type_test) {
          # this was being done with a while & each before, but that didn't seem to be resetting some kind of iterator??
          # this for loop is more reliable for some reason...
          for $controller (keys %{$controllernames{$type_test}}) {
              $controllername = $controllernames{$type_test}{$controller};
              if ($isanimation) {
                  if (readkeyedcontroller($line, $modelref, $nodenum, $animnum, $ASCIIFILE, $controller, $controllername)) {
                      return 1;
                  }
              } elsif (readsinglecontroller($line, $modelref, $nodenum, $controller, $controllername)) {
                  return 1;
              }
          }
      }
  }
  return 0;
}

###########################################################
# Read in an ascii model
# 
sub readasciimdl {
  my ($buffer, $supercheck, $options) = (@_);
  my ($file, $filepath);
  my %model={};
  my $supermodel;
  my ($nodenum, $nodename, $work, $work2, $count, $nodestart, $ref);
  my $isgeometry = 0;  # true if we are in model geometry, false if in animations
  my $isanimation = 0; # true if we are in animations, false if in geometry
  my $innode = 0;  # true if we are currently processing a node
  my $animnum = 0;
  my $task = "";
  my %nodeindex = (null => -1);
  my ($temp1, $temp2, $temp3, $temp4, $temp5, $f1matches, $f2matches, $pathonly);
  my $t;
  my $ASCIIMDL;

  # set up default options for functionality
  if (!defined($options)) {
    $options = {};
  }
  # use area and angle weighted vertex normal averaging
  if(!defined($options->{use_weights})) {
    $options->{use_weights} = 1;
  }
  # use crease angle test for vertex normal averaging
  if (!defined($options->{use_crease_angle})) {
    $options->{use_crease_angle} = 1;
  }
  # specific crease angle to test for in vertex normal averaging
  if (!defined($options->{crease_angle}) ||
      $options->{crease_angle} < 0 ||
      $options->{crease_angle} > 2 * pi) {
    $options->{crease_angle} = pi / 2;
  }
  # produce vertex data required by the engine based on the faces layout,
  # undo unnecessary doubling of vertices, add required doubling of vertices,
  # force all vertex data to be 1:1 as required by MDX format
  # this option is a 50%+ performance hit, but fixes most model geometry issues
  if (!defined($options->{validate_vertex_data})) {
    $options->{validate_vertex_data} = 1;
  }


  #extract just the name
  $buffer =~ /(.*\\)*(.*)\.mdl/;
  $file = $2;
  $model{'filename'} = $2;
  
  $buffer =~ /(.*)\.mdl/;
  $filepath = $1;
  open($ASCIIMDL, $filepath.".mdl") or die "can't open MDL file $filepath.mdl\n";

  $model{'source'} = "ascii";
  $model{'filepath+name'} = $filepath;
  $pathonly = substr($filepath, 0, length($filepath)-length($model{'filename'}));
  print("$pathonly\n") if $printall;

  # emitter properties
  my $emitter_properties = [
    'deadspace', 'blastRadius', 'blastLength',
    'numBranches', 'controlptsmoothing', 'xgrid', 'ygrid', 'spawntype',
    'update', 'render', 'blend', 'texture', 'chunkname',
    'twosidedtex', 'loop', 'm_bFrameBlending', 'm_sDepthTextureName',
    'm_bUnknown1', 'm_lUnknown2'
  ];
  # emitter flags
  my $emitter_flags = {
    p2p                 => 0x0001,
    p2p_sel             => 0x0002,
    affectedByWind      => 0x0004,
    m_isTinted          => 0x0008,
    bounce              => 0x0010,
    random              => 0x0020,
    inherit             => 0x0040,
    inheritvel          => 0x0080,
    inherit_local       => 0x0100,
    splat               => 0x0200,
    inherit_part        => 0x0400,
    depth_texture       => 0x0800,
    renderorder         => 0x1000
  };
  # prepare emitter regex matches, all properties and flags are handled alike
  my $emitter_prop_match = join('|', @{$emitter_properties});
  my $emitter_flag_match = join('|', keys %{$emitter_flags});
  
  #set some default values
  $model{'bmin'} = [-5, -5, -1];
  $model{'bmax'} = [5, 5, 10];
  $model{'radius'} = 7;
  $model{'numanims'} = 0;
  $model{'animationscale'} = 0.971;
  
  # these values are for the trimesh counter sequence,
  # an odd inverted count the purpose of which is unknown to me
  $model{'meshsequence'} = 98;
  $model{'meshsequencebasis'} = { start => 99, end => 0 };

  # read in the ascii mdl
  while (<$ASCIIMDL>) {
    my $line = $_;
    if ($line =~ /beginmodelgeom/i) { # look for the start of the model
      #print("begin model\n");
      $nodenum = 0;
      $isgeometry = 1;
    } elsif ($line =~ /endmodelgeom/i) { # look for the end of the model
      #print("end model\n");
      $isgeometry = 0;
      $nodenum = 0;
    } elsif ($line =~ /\s*bumpmapped_texture\s+(\S*)/i) { # look for a model-wide bumpmapped texture
      $model{'bumpmapped_texture'}{lc $1} = 1;
    } elsif ($line =~ /\s*newanim\s+(\S*)\s+(\S*)/i) { # look for the start of an animation
      $isanimation = 1; 
      $model{'anims'}{$animnum}{'name'} = $1;
      $model{'numanims'}++;
      $model{'anims'}{$animnum}{'nodelist'} = [];
    } elsif ($line =~ /doneanim/i && $isanimation) { # look for the end of an animation
      $isanimation = 0;
      $animnum++;
    } elsif ($line =~ /\s*length\s+(\S*)/i && $isanimation) {
      $model{'anims'}{$animnum}{'length'} = $1;
    } elsif ($line =~ /\s*animroot\s+(\S*)/i && $isanimation) {
      $model{'anims'}{$animnum}{'animroot'} = $1;
    } elsif ($line =~ /\s*transtime\s+(\S*)/i && $isanimation) {
      $model{'anims'}{$animnum}{'transtime'} = $1; 
    } elsif ($line =~ /\s*newmodel\s+(\S*)/i) { # look for the model name
      $model{'name'} = $1;
    } elsif ($line =~ /\s*setsupermodel\s+(\S*)\s+(\S*)/i) { #look for the super model
      $model{'supermodel'} = $2;
    } elsif (!$innode && $line =~ /\s*bmin\s+(\S*)\s+(\S*)\s+(\S*)/i) { #look for the bounding box min
      $model{'bmin'} = [$1,$2,$3];
    } elsif (!$innode && $line =~ /\s*bmax\s+(\S*)\s+(\S*)\s+(\S*)/i) { #look for the bounding box max
      $model{'bmax'} = [$1,$2,$3];
    } elsif ($innode && $line =~ /\s*bmin\s+(\S*)\s+(\S*)\s+(\S*)/i) { #look for the mesh bounding box min
      $model{nodes}{$nodenum}{'bboxmin'} = [$1,$2,$3];
    } elsif ($innode && $line =~ /\s*bmax\s+(\S*)\s+(\S*)\s+(\S*)/i) { #look for the mesh bounding box max
      $model{nodes}{$nodenum}{'bboxmax'} = [$1,$2,$3];
    } elsif ($innode && ($model{'nodes'}{$nodenum}{'nodetype'} & NODE_HAS_MESH) && $line =~ /^\s*radius\s+(\S+)/i) { #look for the mesh radius
      $model{nodes}{$nodenum}{'radius'} = $1;
    } elsif ($innode && $line =~ /\s*average\s+(\S*)\s+(\S*)\s+(\S*)/i) { #look for the mesh average point
      $model{nodes}{$nodenum}{'average'} = [$1,$2,$3];
    } elsif ($line =~ /\s*classification\s+(\S*)/i) { # look for the model type
      # using this as a key into the classifications hash, so format the string
      $model{'classification'} = ucfirst lc $1;
    } elsif (!$innode && $line =~ /\s*radius\s+(\S*)/i) {
      $model{'radius'} = $1;
    } elsif ($line =~ /\s*setanimationscale\s+(\S*)/i) {
      $model{'animationscale'} = $1;
    } elsif ($innode && $line =~ /^\s*($emitter_prop_match)\s+(\S+)\s*$/i) {
      $model{'nodes'}{$nodenum}{$1} = $2;
    } elsif ($innode && $line =~ /^\s*($emitter_flag_match)\s+(\S+)\s*$/i) {
      if (!defined($model{'nodes'}{$nodenum}{'emitterflags'})) {
        $model{'nodes'}{$nodenum}{'emitterflags'} = 0;
      }
      if ($2 == 1) {
        $model{'nodes'}{$nodenum}{'emitterflags'} |= $emitter_flags->{$1};
      }
      $model{'nodes'}{$nodenum}{$1} = int $2;
      next;
    } elsif (!$innode && $line =~ /\s*node\s+(\S*)\s+(\S*)/i && $isanimation) { # look for the start of an animation node
      $innode = 1;
      $nodenum = $nodeindex{lc($2)};
      push @{$model{'anims'}{$animnum}{'nodelist'}}, $nodenum;
      $model{'anims'}{$animnum}{'nodes'}{'numnodes'}++;
      $model{'anims'}{$animnum}{'nodes'}{$nodenum}{'nodenum'} = $nodenum;
      $model{'anims'}{$animnum}{'nodes'}{$nodenum}{'nodetype'} = $nodelookup{'dummy'};
      $model{'anims'}{$animnum}{'nodes'}{$nodenum}{'controllernum'} = 0;
      $model{'anims'}{$animnum}{'nodes'}{$nodenum}{'controllerdatanum'} = 0;
      $model{'anims'}{$animnum}{'nodes'}{$nodenum}{'childcount'} = 0;
      $model{'anims'}{$animnum}{'nodes'}{$nodenum}{'children'} = [];
    } elsif ($innode && $line =~ /endnode/i && $isanimation) { # look for the end of an animation node
      $innode = 0;
    } elsif ($innode && $line =~ /endnode/i && $isgeometry) { # look for the end of a geometry node
      $nodenum++;
      $innode = 0;
      $task = "";
      $model{'nodes'}{$nodenum}{'header'} = {};
    } elsif (!$innode && $line =~ /\s*node\s+(\S*)\s+(\S*)/i && $isgeometry) { # look for the start of a geometry node
      my ($ntype, $nname) = (lc($1), $2);
      # handle saber, currently tracked as a name prefix rather than a type
      if ($nname =~ /^2081__/) {
        # type should have been 'trimesh', make it 'saber'
        $ntype = 'saber';
        $nname =~ s/^2081__//;
      }
      my $nname_key = lc($nname);
      $model{'nodes'}{'truenodenum'}++;
      $innode = 1;
      $model{'nodes'}{$nodenum}{'nodenum'} = $nodenum;
      $model{'nodes'}{$nodenum}{'render'} = 1;
      $model{'nodes'}{$nodenum}{'shadow'} = 0;
      $model{'nodes'}{$nodenum}{'nodetype'} = $nodelookup{$ntype};
      # determine the MDX data size from the node type
      # we will recalculate this more accurately based on known data later
      if ($model{'nodes'}{$nodenum}{'nodetype'} & NODE_HAS_SKIN) { # skin mesh
        $model{'nodes'}{$nodenum}{'mdxdatasize'} = 64;
        $model{'nodes'}{$nodenum}{'texturenum'} = 1;
      } elsif ($model{'nodes'}{$nodenum}{'nodetype'} & NODE_HAS_DANGLY) { # dangly mesh
        $model{'nodes'}{$nodenum}{'mdxdatasize'} = 32;
        $model{'nodes'}{$nodenum}{'texturenum'} = 1;
      } else {
        $model{'nodes'}{$nodenum}{'mdxdatasize'} = 24; # tri mesh with no texture map
        $model{'nodes'}{$nodenum}{'texturenum'} = 0;
      }
      # handle mesh sequence counter
      if ($model{'nodes'}{$nodenum}{'nodetype'} & NODE_HAS_MESH) {
        # assign mesh sequence counter
        $model{'nodes'}{$nodenum}{'array3'} = $model{'meshsequence'};
        # prepare next mesh sequence counter number
        # modeling a strange sequence... 98..0, 100,199..101, 200,299..201
        # if anyone ever reads the following lines of code ... sorry.
        if ($model{'meshsequence'} > $model{'meshsequencebasis'}->{start}) {
          # set end of next range to current value + 1
          $model{'meshsequencebasis'}->{end} = $model{'meshsequence'} + 1;
          # set current value to start of previous range + 100
          $model{'meshsequence'} = $model{'meshsequencebasis'}->{start} + 100;
          # set start of next range to current range start + 100
          $model{'meshsequencebasis'}->{start} += 100;
        }
        # decrement the counter
        $model{'meshsequence'} -= 1;
        if ($model{'meshsequence'} < $model{'meshsequencebasis'}->{end}) {
          # if we decrement past our range basis, set next value to upper limit + 1
          $model{'meshsequence'} = $model{'meshsequencebasis'}->{start} + 1
        }
      }
      # number of textures will be added to as they are found in parsing
      $model{'nodes'}{$nodenum}{'texturenum'} = 0;
      $model{'nodes'}{$nodenum}{'mdxdatabitmap'} = 0;
      # set to 1 if node's smooth group numbers are all powers of 2, otherwise 0
      $model{'nodes'}{$nodenum}{'sg_base2'} = 1;
      $model{'nodes'}{$nodenum}{'bboxmin'} = [-5, -5, -5];
      $model{'nodes'}{$nodenum}{'bboxmax'} = [5, 5, 5];
      $model{'nodes'}{$nodenum}{'radius'} = 10;
      $model{'nodes'}{$nodenum}{'average'} = [0, 0, 0];
      $model{'nodes'}{$nodenum}{'diffuse'} = [0.8, 0.8, 0.8];
      $model{'nodes'}{$nodenum}{'ambient'} = [0.2, 0.2, 0.2];
      $model{'nodes'}{$nodenum}{'controllernum'} = 0;
      $model{'nodes'}{$nodenum}{'controllerdatanum'} = 0;
      $model{'nodes'}{$nodenum}{'childcount'} = 0;
      $model{'nodes'}{$nodenum}{'children'} = [];
      #$model{'nodes'}{$nodenum}{'nodetype'} = $nodelookup{$ntype};
      $model{'partnames'}[$nodenum] = $nname;
      #node index has the text node name (in lower case) as keys and node number as values
      $nodeindex{$nname_key} = $nodenum;
      $model{'nodeindex'}{$nname_key} = $nodenum;
    } elsif ($innode && $line =~ /^\s*radius\s+(\S*)/i && $model{'nodes'}{$nodenum}{'nodetype'} != $nodelookup{'light'}) {
      $model{'radius'} = $1;

    } elsif (readasciicontroller($line, $model{'nodes'}{$nodenum}{'nodetype'}, $innode, $isanimation, \%model, $nodenum, $animnum, $ASCIIMDL)) {

    } elsif ($innode && $line =~ /\s*parent\s*(\S*)/i) { # if in a node look for the parent property
      if ($isgeometry) {
        $ref = $model{'nodes'};
      } else {
        $ref = $model{'anims'}{$animnum}{'nodes'};
      }
      $ref->{$nodenum}{'parent'} = $1;
      #translate the parents text name into the parents node number
      $ref->{$nodenum}{'parentnodenum'} = $nodeindex{lc($1)};
      if ($ref->{$nodenum}{'parentnodenum'} != -1) {
        #record what position in the parents child list this node is in
        $ref->{$nodenum}{'childposition'} = $ref->{ $ref->{$nodenum}{'parentnodenum'} }{'childcount'};
        #increment the parents child list
        $ref->{ $ref->{$nodenum}{'parentnodenum'} }{'children'}[$ref->{$nodenum}{'childposition'}] = $nodenum;
        $ref->{ $ref->{$nodenum}{'parentnodenum'} }{'childcount'}++;
      }
    } elsif ($innode && $line =~ /\s*flareradius\s+(\S*)/i) { # if in a node look for the flareradius property
      $model{'nodes'}{$nodenum}{'flareradius'} = $1;
    } elsif ($innode && $line =~ /\s*(flarepositions|flaresizes|flarecolorshifts|texturenames)\s+(\S*)/i) {
      $task = '';
      $count = 0;
      if ($2 > 0) {
        # there are flare data to read, initialize task list:
        $model{'nodes'}{$nodenum}{$1} = [];
        # set flarepositionsnum, flaresizesnum, flarecolorshiftsnum, or texturenamesnum
        $model{'nodes'}{$nodenum}{$1 . 'num'} = int $2;
        $task = $1;
      }
    } elsif ($innode && $line =~ /\s*ambientonly\s+(\S*)/i) { # if in a node look for the ambientonly property
      $model{'nodes'}{$nodenum}{'ambientonly'} = $1;
    } elsif ($innode && $line =~ /\s*ndynamictype\s+(\S*)/i) { # if in a node look for the ndynamictype property
      $model{'nodes'}{$nodenum}{'ndynamictype'} = $1;
    } elsif ($innode && $line =~ /\s*affectdynamic\s+(\S*)/i) { # if in a node look for the affectDynamic property
      $model{'nodes'}{$nodenum}{'affectdynamic'} = $1;
    } elsif ($innode && $line =~ /\s*flare\s+(\S*)/i) { # if in a node look for the flare property
      $model{'nodes'}{$nodenum}{'flare'} = $1;
    } elsif ($innode && $line =~ /\s*lightpriority\s+(\S*)/i) { # if in a node look for the lightpriority property
      $model{'nodes'}{$nodenum}{'lightpriority'} = $1;
    } elsif ($innode && $line =~ /\s*fadinglight\s+(\S*)/i) { # if in a node look for the fadinglight property
      $model{'nodes'}{$nodenum}{'fadinglight'} = $1;
    } elsif ($innode && $line =~ /\s*render\s+(\S*)/i) { # if in a node look for the render property
      $model{'nodes'}{$nodenum}{'render'} = $1;
    } elsif ($innode && $line =~ /\s*shadow\s+(\S*)/i) { # if in a node look for the shadow property
      $model{'nodes'}{$nodenum}{'shadow'} = $1;
    } elsif ($innode && $line =~ /\s*lightmapped\s+(\S*)/i) { # if in a node look for the lightmapped property
      $model{'nodes'}{$nodenum}{'lightmapped'} = $1;
    } elsif ($innode && $line =~ /\s*rotatetexture\s+(\S*)/i) { # if in a node look for the rotatetexture property
      $model{'nodes'}{$nodenum}{'rotatetexture'} = $1;
    } elsif ($innode && $line =~ /\s*m_bIsBackgroundGeometry\s+(\S*)/i) { # if in a node look for the BackgroundGeometry property
      $model{'nodes'}{$nodenum}{'m_bIsBackgroundGeometry'} = $1;
    } elsif ($innode && $line =~ /\s*beaming\s+(\S*)/i) { # if in a node look for the beaming property
      $model{'nodes'}{$nodenum}{'beaming'} = $1;
    } elsif ($innode && $line =~ /\s*transparencyhint\s+(\S*)/i) { # if in a node look for the transparencyhint property
      $model{'nodes'}{$nodenum}{'transparencyhint'} = $1;
    } elsif ($innode && $line =~ /\s*dirt_enabled\s+(\S*)/i) { # if in a node look for the k2 dirt_enabled property
      $model{'nodes'}{$nodenum}{'dirt_enabled'} = $1;
    } elsif ($innode && $line =~ /\s*dirt_texture\s+(\S*)/i) { # if in a node look for the k2 dirt_texture property
      $model{'nodes'}{$nodenum}{'dirt_texture'} = $1;
    } elsif ($innode && $line =~ /\s*dirt_worldspace\s+(\S*)/i) { # if in a node look for the k2 dirt_worldspace property
      $model{'nodes'}{$nodenum}{'dirt_worldspace'} = $1;
    } elsif ($innode && $line =~ /\s*hologram_donotdraw\s+(\S*)/i) { # if in a node look for the k2 hologram_donotdraw property
      $model{'nodes'}{$nodenum}{'hologram_donotdraw'} = $1;
    } elsif ($innode && $line =~ /\s*animateuv\s+(\S*)/i) { # if in a node look for the animateuv property
      $model{'nodes'}{$nodenum}{'animateuv'} = $1;
    } elsif ($innode && $line =~ /\s*uvdirectionx\s+(\S*)/i) { # if in a node look for the uvdirectionx property
      $model{'nodes'}{$nodenum}{'uvdirectionx'} = $1;
    } elsif ($innode && $line =~ /\s*uvdirectiony\s+(\S*)/i) { # if in a node look for the uvdirectiony property
      $model{'nodes'}{$nodenum}{'uvdirectiony'} = $1;
    } elsif ($innode && $line =~ /\s*uvjitter\s+(\S*)/i) { # if in a node look for the uvjitter property
      $model{'nodes'}{$nodenum}{'uvjitter'} = $1;
    } elsif ($innode && $line =~ /\s*uvjitterspeed\s+(\S*)/i) { # if in a node look for the uvjitterspeed property
      $model{'nodes'}{$nodenum}{'uvjitterspeed'} = $1;
    } elsif ($innode && $line =~ /\s*diffuse\s+(\S*)\s+(\S*)\s+(\S*)/i) { # if in a node look for the diffuse property
      $model{'nodes'}{$nodenum}{'diffuse'} = [$1, $2, $3];
    } elsif ($innode && $line =~ /\s*ambient\s+(\S*)\s+(\S*)\s+(\S*)/i) {  # if in a node look for the ambient property
      $model{'nodes'}{$nodenum}{'ambient'} = [$1, $2, $3];
    } elsif ($innode && $line =~ /\s*specular\s+(\S*)\s+(\S*)\s+(\S*)/i) {  # if in a node look for the specular property
      # specular numbers are not used, have no place in binary models
      $model{'nodes'}{$nodenum}{'specular'} = [$1, $2, $3];
    } elsif ($innode && $line =~ /\s*shininess\s+(\S*)/i) {  # if in a node look for the shininess property
      # shininess numbers are not used, have no place in binary models
      $model{'nodes'}{$nodenum}{'shininess'} = $1;
    } elsif ($innode && $line =~ /\s*bitmap\s+(\S*)/i) {  # if in a node look for the bitmap property
      $model{'nodes'}{$nodenum}{'bitmap'} = $1;
      # if this is a bump mapped texture, indicate that we need tangent space calculations
      if (defined($model{'bumpmapped_texture'}) &&
          defined($model{'bumpmapped_texture'}{lc $1})) {
          $model{'nodes'}{$nodenum}{'mdxdatabitmap'} |= MDX_TANGENT_SPACE;
      }
      $model{'nodes'}{$nodenum}{'bitmap2'} = "";
      $model{'nodes'}{$nodenum}{'texture0'} = "";
      $model{'nodes'}{$nodenum}{'texture1'} = "";
    } elsif ($innode && $line =~ /\s*bitmap2\s+(\S*)/i) {  # if in a node look for the bitmap2 property
      $model{'nodes'}{$nodenum}{'bitmap2'} = $1;
    } elsif ($innode && $line =~ /\s*texture0\s+(\S*)/i) {  # if in a node look for the texture0 property
      $model{'nodes'}{$nodenum}{'texture0'} = $1;
    } elsif ($innode && $line =~ /\s*texture1\s+(\S*)/i) {  # if in a node look for the texture1 property
      $model{'nodes'}{$nodenum}{'texture1'} = $1;
    } elsif ($innode && $line =~ /\s*displacement\s+(\S*)/i) { # if in a node look for the displacement property
      $model{'nodes'}{$nodenum}{'displacement'} = $1;
    } elsif ($innode && $line =~ /\s*tightness\s+(\S*)/i) { # if in a node look for the tightness property
      $model{'nodes'}{$nodenum}{'tightness'} = $1;
    } elsif ($innode && $line =~ /\s*period\s+(\S*)/i) { # if in a node look for the period property
      $model{'nodes'}{$nodenum}{'period'} = $1;
    } elsif (!$innode && $line =~ /^\s*event\s+(\S+)\s+(\S+)/i && $isanimation) { # if in an animation look for the events
      if (!defined($model{'anims'}{$animnum}{'numevents'})) {
        $model{'anims'}{$animnum}{'numevents'} = 0;
      }
      $model{'anims'}{$animnum}{'eventtimes'}[$count] = $1;
      $model{'anims'}{$animnum}{'eventnames'}[$count] = $2;
      $model{'anims'}{$animnum}{'numevents'}++;
    } elsif (!$innode && $line =~ /eventlist/i && $isanimation) { # if in an animation look for the start of the event list
      $task = "events";
      $model{'anims'}{$animnum}{'numevents'} = 0;
      $count = 0;      
    } elsif (!$innode && $line =~ /endlist/i && $isanimation) { # if in an animation look for the end of the event list
      $task = "";
      $count = 0;
    } elsif ($innode && $line =~ /\s*[^t]verts\s+(\S*)/i) {  # if in a node look for the start of the verts
      $model{'nodes'}{$nodenum}{'vertnum'} = $1;
      $model{'nodes'}{$nodenum}{'mdxdatabitmap'} |= MDX_VERTICES | MDX_VERTEX_NORMALS;
      $task = "verts";
      $count = 0;
    } elsif ($innode && $line =~ /\s*faces\s+(\S*)/i) { # if in a node look for the start of the faces
      $model{'nodes'}{$nodenum}{'facesnum'} = $1;
      $model{'nodes'}{$nodenum}{'vertfaces'} = {};
      $task = "faces";
      $count = 0;
    } elsif ($innode && $line =~ /\s*tverts\s+(\S*)/i) { # if in a node look for the start of the tverts
      $model{'nodes'}{$nodenum}{'tvertsnum'} = $1;
      # if this is a tri mesh with tverts then adjust the MDX data size
      if ($model{'nodes'}{$nodenum}{'nodetype'} == NODE_TRIMESH) {
        $model{'nodes'}{$nodenum}{'mdxdatasize'} = 32;
      }
      $model{'nodes'}{$nodenum}{'texturenum'} += 1;
      $model{'nodes'}{$nodenum}{'mdxdatabitmap'} |= MDX_TEX0_VERTICES;
      #print($task . "|" . $count . "\n");
      $task = "tverts";
      $count = 0;
    } elsif ($innode && $line =~ /\s*tverts1\s+(\S*)/i) { # if in a node look for the start of the tverts for 2nd texture
      $model{'nodes'}{$nodenum}{'tverts1num'} = $1;
      $model{'nodes'}{$nodenum}{'texturenum'} += 1;
      $model{'nodes'}{$nodenum}{'mdxdatabitmap'} |= MDX_TEX1_VERTICES;
      #print($task . "|" . $count . "\n");
      $task = "tverts1";
      $count = 0;
    } elsif ($innode && $line =~ /\s*tverts2\s+(\S*)/i) { # if in a node look for the start of the tverts for 3rd texture
      $model{'nodes'}{$nodenum}{'tverts2num'} = $1;
      $model{'nodes'}{$nodenum}{'texturenum'} += 1;
      $model{'nodes'}{$nodenum}{'mdxdatabitmap'} |= MDX_TEX2_VERTICES;
      #print($task . "|" . $count . "\n");
      $task = "tverts2";
      $count = 0;
    } elsif ($innode && $line =~ /\s*tverts3\s+(\S*)/i) { # if in a node look for the start of the tverts for 4th texture
      $model{'nodes'}{$nodenum}{'tverts3num'} = $1;
      $model{'nodes'}{$nodenum}{'texturenum'} += 1;
      $model{'nodes'}{$nodenum}{'mdxdatabitmap'} |= MDX_TEX3_VERTICES;
      #print($task . "|" . $count . "\n");
      $task = "tverts3";
      $count = 0;
    } elsif ($innode && $line =~ /\s*[^t]verts1\s+(\S*)/i) {  # if in a node look for the start of the saber verts1
      $model{'nodes'}{$nodenum}{'verts1num'} = $1;
      $task = "verts1";
      $count = 0;
    } elsif ($innode && $line =~ /\s*[^t]tverts1offset\s+(\S*)/i) {  # if in a node look for the start of the saber tverts1offset
      $model{'nodes'}{$nodenum}{'tverts1offsetnum'} = $1;
      $task = "tverts1offset";
      $count = 0;
    } elsif ($innode && $line =~ /\s*weights\s+(\S*)/i) { # if in a node look for the start of the weights
      $model{'nodes'}{$nodenum}{'weightsnum'} = $1;
      #print($task . "|" . $count . "\n");
      $task = "weights";
      $count = 0;
    } elsif ($innode && $line =~ /\s*constraints\s+(\S*)/i) { # if in a node look for the start of the constraints
      $model{'nodes'}{$nodenum}{'constraintnum'} = $1;
      #print($task . "|" . $count . "\n");
      $task = "constraints";
      $count = 0;
    } elsif ($innode && $line =~ /\s*aabb/i) { # if in a node look for the start of the constraints
      #print("Found aabb\n");
      #print($task . "|" . $count . "\n");
      $task = "aabb";
      $count = 0;
      if($line =~ /\s*aabb\s*(\S*)\s+(\S*)\s+(\S*)\s+(\S*)\s+(\S*)\s+(\S*)\s+(\S*)/i) {
        $model{'nodes'}{$nodenum}{'aabbnodes'}[$count] = [$1, $2, $3, $4, $5, $6, $7];
        $count++;
      }
    } elsif (!$innode && $isanimation && $task eq "events") { # if in an animation read in events
      $line =~ /\s+(\S*)\s+(\S*)/;
      $model{'anims'}{$animnum}{'eventtimes'}[$count] = $1;
      $model{'anims'}{$animnum}{'eventnames'}[$count] = $2;
      $model{'anims'}{$animnum}{'numevents'}++;
      $count++;      
    } elsif ($innode && $isanimation) { # if in an animation node read in controllers
    } elsif ($innode && $isgeometry && $task ne '') {  # if in a node and in verts, faces, tverts or constraints read them in
      if (defined($model{'nodes'}{$nodenum}{$task . 'num'}) &&
          $count >= $model{'nodes'}{$nodenum}{$task . 'num'}) {
        # this isn't going to end all of the numbered data gathering tasks
        # that are currently implemented, but it will end the ones that use
        # the normal naming conventions...
        $task = '';
        $count = 0;
      }
      if ($task eq "verts" ) { # read in the verts
        $line =~ /\s*(\S*)\s+(\S*)\s+(\S*)/;
        $model{'nodes'}{$nodenum}{'verts'}[$count] = [$1, $2, $3];
        $count++;
      } elsif ($task eq "faces") { # read in the faces
        $line =~ /\s*(\S*)\s+(\S*)\s+(\S*)\s+(\S*)\s+(\S*)\s+(\S*)\s+(\S*)\s+(\S*)/;
        $model{'nodes'}{$nodenum}{'Afaces'}[$count] = "$1 $2 $3 $4 $5 $6 $7 $8";
        $model{'nodes'}{$nodenum}{'Bfaces'}[$count] = [0, 0, 0, 0, $4, -1, -1, -1, $1, $2, $3 ];

        # temporary list of uvs associated with each face, deleted after vertex validation
        if (!defined($model{'nodes'}{$nodenum}{'faceuvs'})) {
          $model{'nodes'}{$nodenum}{'faceuvs'} = [];
        }
        $model{'nodes'}{$nodenum}{'faceuvs'}->[$count] = [ int($5), int($6), int($7) ];
        if ( defined($model{'nodes'}{$nodenum}{'vertfaces'}{$1}[0]) )
        {
          push @{$model{'nodes'}{$nodenum}{'vertfaces'}{$1}}, $count;
        }
        else
        {
          $model{'nodes'}{$nodenum}{'vertfaces'}{$1} = [$count];
        }

        if ( defined($model{'nodes'}{$nodenum}{'vertfaces'}{$2}[0]) )
        {
          push @{$model{'nodes'}{$nodenum}{'vertfaces'}{$2}}, $count;
        }
        else
        {
          $model{'nodes'}{$nodenum}{'vertfaces'}{$2} = [$count];
        }

        if ( defined($model{'nodes'}{$nodenum}{'vertfaces'}{$3}[0]) )
        {
          push @{$model{'nodes'}{$nodenum}{'vertfaces'}{$3}}, $count;
        }
        else
        {
          $model{'nodes'}{$nodenum}{'vertfaces'}{$3} = [$count];
        }

        if (!defined($model{'nodes'}{$nodenum}{'tverti'}{$1}))
        {
          $model{'nodes'}{$nodenum}{'tverti'}{$1} = $5;
        }

        if (!defined($model{'nodes'}{$nodenum}{'tverti'}{$2}))
        {
          $model{'nodes'}{$nodenum}{'tverti'}{$2} = $6;
        }

        if (!defined($model{'nodes'}{$nodenum}{'tverti'}{$3}))
        {
          $model{'nodes'}{$nodenum}{'tverti'}{$3} = $7;
        }

        # test whether smooth group number is base 2
        # if ALL smooth group numbers in the node ARE a power of 2,
        # they will be reduced to log base 2 before being written to binary.
        # otherwise smooth group numbers will be left as is.
        if ($4 > 0 && (log($4) / log(2)) =~ /\D/)
        {
          # logarithm contained a non-digit (.) so not a clean power of 2
          $model{'nodes'}{$nodenum}{'sg_base2'} = 0;
        }

        $count++;

      } elsif ($task eq "tverts") { # read in the tverts
        $line =~ /\s*(\S*)\s+(\S*)\s+(\S*)/;
        $model{'nodes'}{$nodenum}{'tverts'}[$count] = [$1, $2];
        $count++;
      } elsif ($task eq "tverts1") { # read in the tverts for 2nd texture
        $line =~ /\s*(\S*)\s+(\S*)\s+(\S*)/;
        $model{'nodes'}{$nodenum}{'tverts1'}[$count] = [$1, $2];
        $count++;
      } elsif ($task eq "tverts2") { # read in the tverts for 3rd texture
        $line =~ /\s*(\S*)\s+(\S*)\s+(\S*)/;
        $model{'nodes'}{$nodenum}{'tverts2'}[$count] = [$1, $2];
        $count++;
      } elsif ($task eq "tverts3") { # read in the tverts for 4th texture
        $line =~ /\s*(\S*)\s+(\S*)\s+(\S*)/;
        $model{'nodes'}{$nodenum}{'tverts3'}[$count] = [$1, $2];
        $count++;
      } elsif ($task eq "verts1" ) { # read in the verts1 saber data
        $line =~ /\s*(\S*)\s+(\S*)\s+(\S*)/;
        $model{'nodes'}{$nodenum}{'verts1'}[$count] = [$1, $2, $3];
        $count++;
      } elsif ($task eq "tverts1offset" ) { # read in the tverts1offset saber data
        $line =~ /\s*(\S*)\s+(\S*)\s+(\S*)/;
        $model{'nodes'}{$nodenum}{'tverts1offset'}[$count] = [$1, $2, $3];
        $count++;
      } elsif ($task eq "weights") { # read in the bone weights
        $line =~ /\s*(\S*)\s*(\S*)\s*(\S*)\s*(\S*)\s*(\S*)\s*(\S*)\s*(\S*)\s*(\S*)/;
        $model{'nodes'}{$nodenum}{'Abones'}[$count] = "$1 $2";
        $model{'nodes'}{$nodenum}{'bones'}[$count][0] = $1;
        $model{'nodes'}{$nodenum}{'weights'}[$count][0] = $2;
        if ($3 ne "") {
          $model{'nodes'}{$nodenum}{'Abones'}[$count] .= " $3 $4";
          $model{'nodes'}{$nodenum}{'bones'}[$count][1] = $3;
          $model{'nodes'}{$nodenum}{'weights'}[$count][1] = $4;
          if ($5 ne "") {
            $model{'nodes'}{$nodenum}{'Abones'}[$count] .= " $5 $6";
            $model{'nodes'}{$nodenum}{'bones'}[$count][2] = $5;
            $model{'nodes'}{$nodenum}{'weights'}[$count][2] = $6;
            if ($7 ne "") {
              $model{'nodes'}{$nodenum}{'Abones'}[$count] .= " $7 $8";
              $model{'nodes'}{$nodenum}{'bones'}[$count][3] = $7;
              $model{'nodes'}{$nodenum}{'weights'}[$count][3] = $8;
            }
          }
        }
        $count++;
      } elsif ($task eq "constraints") { # read in the constraints
        $line =~ /\s*(\S*)/;
        $model{'nodes'}{$nodenum}{'constraints'}[$count] = $1;
        $count++;
      } elsif ($task eq "aabb") { # read in the aabb stuff
        $line =~ /\s*(\S*)\s+(\S*)\s+(\S*)\s+(\S*)\s+(\S*)\s+(\S*)\s+(\S*)/;
        $model{'nodes'}{$nodenum}{'aabbnodes'}[$count] = [$1, $2, $3, $4, $5, $6, $7];
        $count++;
      } elsif ($task eq 'flarepositions' ||
               $task eq 'flaresizes' ||
               $task eq 'texturenames') {
        $line =~ /\s*(\S*)/;
        $model{'nodes'}{$nodenum}{$task} = [
          @{$model{'nodes'}{$nodenum}{$task}}, $1
        ];
        $count++;
      } elsif ($task eq 'flarecolorshifts') {
        $line =~ /\s*(\S*)\s+(\S*)\s+(\S*)/;
        $model{'nodes'}{$nodenum}{$task} = [
          @{$model{'nodes'}{$nodenum}{$task}}, [ $1, $2, $3 ]
        ];
        $count++;
      } # if ($task eq "verts" )
    } # the big IF
  } # while (<$ASCIIMDL>)

  #$model{'nodes'}{'truenodenum'} = $nodenum;
  
  # if this model has a super model then open the original model
  # and set the supernodes on the working model
  $model{'largestsupernode'} = 0;
  print ( lc($model{'supermodel'}) . "|" . $supercheck . "\n") if $printall;
  if (lc($model{'supermodel'}) ne "null" && $supercheck == 1) {
    print("Loading original binary model: " . $pathonly . $model{'name'} . ".mdl\n");
    #$supermodel = &readbinarymdl($pathonly . $model{'supermodel'} . ".mdl", 0);
    $supermodel = &readbinarymdl($pathonly . $model{'name'} . ".mdl", 0, modelversion($pathonly . $model{'name'} . ".mdl"));
    foreach (keys %{$supermodel->{'nodes'}} ) {
      if ($_ eq "truenodenum") {next;}
      if ($supermodel->{'nodes'}{$_}{'supernode'} > $model{'largestsupernode'}) {
        $model{'largestsupernode'} = $supermodel->{'nodes'}{$_}{'supernode'};
      }
      if ( defined( $nodeindex{ lc( $supermodel->{'partnames'}[$_] ) } ) ) {
        if ($supermodel->{'nodes'}{$_}{'nodetype'} == NODE_SKIN) {
          $model{'nodes'}{$nodeindex{lc($supermodel->{'partnames'}[$_])}}{'qbones'}{'unpacked'} = [ @{$supermodel->{'nodes'}{$_}{'qbones'}{'unpacked'}} ];
          $model{'nodes'}{$nodeindex{lc($supermodel->{'partnames'}[$_])}}{'tbones'}{'unpacked'} = [ @{$supermodel->{'nodes'}{$_}{'tbones'}{'unpacked'}} ];
          $model{'nodes'}{$nodeindex{lc($supermodel->{'partnames'}[$_])}}{'array8'}{'unpacked'} = [ @{$supermodel->{'nodes'}{$_}{'array8'}{'unpacked'}} ];
        }
        $model{'nodes'}{$nodeindex{lc($supermodel->{'partnames'}[$_])}}{'supernode'} = $supermodel->{'nodes'}{$_}{'supernode'};
      }
    }
    $supermodel = undef;
    print("original model is version: " . modelversion($pathonly . $model{'name'} . ".mdl") . "\n");
  }

  # make sure we have the right node number - we weren't processing a bunch of the nodes at the end!
  $nodenum = $model{'nodes'}{'truenodenum'};

  # rework node geometry according to the requirements of the MDX data format,
  # making all of the per-vertex data correlated, as if we had vertex objects
  if ($options->{validate_vertex_data}) {
    for (my $i = 0; $i < $nodenum; $i++)
    {
      if (!($model{nodes}{$i}{nodetype} & NODE_HAS_MESH) ||
          $model{nodes}{$i}{nodetype} & NODE_HAS_SABER ||
          $model{nodes}{$i}{nodetype} & NODE_HAS_AABB) {
        next;
      }
      # temporary data structures for this node's new data
      my $verts       = [];
      my $Afaces      = [];
      my $Bfaces      = [];
      my $vertfaces   = {};
      my $sgroups     = [];
      my $tverts      = [];
      my $tverts1     = [];
      my $tverts2     = [];
      my $tverts3     = [];
      my $tvertsi     = {};
      my $Abones      = [];
      my $bones       = [];
      my $weights     = [];
      # precompute the types of optional vertex data in use by this node
      my $use_skin    = ($model{nodes}{$i}{nodetype} & NODE_HAS_SKIN);
      my $use_tverts  = ($model{nodes}{$i}{'mdxdatabitmap'} & MDX_TEX0_VERTICES);
      my $use_tverts1 = ($model{nodes}{$i}{'mdxdatabitmap'} & MDX_TEX1_VERTICES);
      my $use_tverts2 = ($model{nodes}{$i}{'mdxdatabitmap'} & MDX_TEX2_VERTICES);
      my $use_tverts3 = ($model{nodes}{$i}{'mdxdatabitmap'} & MDX_TEX3_VERTICES);
      # go through all faces, by face index
      for my $face_index (keys @{$model{'nodes'}{$i}{'Afaces'}}) {
        # construct a face structure that contains all the original ascii data,
        # this construction saves a half second on my 7.3s reference character compile
        # versus splitting the ascii face:
        #my $face = [ split(/\s+/, $model{'nodes'}{$i}{'Afaces'}[$face_index]) ];
        my $face = [
          @{$model{'nodes'}{$i}{'Bfaces'}[$face_index]}[8..10],
          $model{'nodes'}{$i}{'Bfaces'}[$face_index][4],
          0, 0, 0, 0
        ];
        if ($use_tverts || $use_tverts1 || $use_tverts2 || $use_tverts3) {
          # doesn't work because tverti is only accurate when geometry is already correct
          #$face->[4] = $model{'nodes'}{$i}{'tverti'}{$face->[0]};
          #$face->[5] = $model{'nodes'}{$i}{'tverti'}{$face->[1]};
          #$face->[6] = $model{'nodes'}{$i}{'tverti'}{$face->[2]};
          # instead, we made a new structure to track these, it will be deleted!
          $face->[4] = $model{'nodes'}{$i}{'faceuvs'}->[$face_index][0];
          $face->[5] = $model{'nodes'}{$i}{'faceuvs'}->[$face_index][1];
          $face->[6] = $model{'nodes'}{$i}{'faceuvs'}->[$face_index][2];
        }
        # empty templates for this face's data
        my $new_Aface = '';
        my $new_Bface = [ 0, 0, 0, 0, int($face->[3]), -1, -1, -1, 0, 0, 0 ];
        # retain the face's vertex positions in easier to use structure
        my $face_verts = [
          @{$model{'nodes'}{$i}{verts}}[@{$face}[0..2]]
        ];
        # retain the face's texture vertex positions (if used) in convenient structure
        my $face_tverts = [];
        my $face_tverts1 = [];
        my $face_tverts2 = [];
        my $face_tverts3 = [];
        if ($use_tverts) {
          $face_tverts = [
            @{$model{'nodes'}{$i}{tverts}}[@{$face}[4..6]]
          ];
        }
        if ($use_tverts1) {
          $face_tverts1 = [
            @{$model{'nodes'}{$i}{tverts1}}[@{$face}[4..6]]
          ];
        }
        if ($use_tverts2) {
          $face_tverts2 = [
            @{$model{'nodes'}{$i}{tverts2}}[@{$face}[4..6]]
          ];
        }
        if ($use_tverts3) {
          $face_tverts3 = [
            @{$model{'nodes'}{$i}{tverts3}}[@{$face}[4..6]]
          ];
        }
        # go through the 3 vertices of this face, by face vertex index
        for my $fv_index (0..2) {
          my $match_found = 0;
          # attempt to find matching existing vertex we can use,
          # starting from list end here yields ~50% performance gain
          for my $index (reverse keys @{$verts}) {
            if ((!$use_tverts  || vertex_equals($tverts->[$index],  $face_tverts->[$fv_index],  4)) &&
                (!$use_tverts1 || vertex_equals($tverts1->[$index], $face_tverts1->[$fv_index], 4)) &&
                (!$use_tverts2 || vertex_equals($tverts2->[$index], $face_tverts2->[$fv_index], 4)) &&
                (!$use_tverts3 || vertex_equals($tverts3->[$index], $face_tverts3->[$fv_index], 4)) &&
                ($sgroups->[$index] & int($face->[3])) &&
                vertex_equals($verts->[$index], $face_verts->[$fv_index], 4)) {
              # existing vertex matches on all criteria, use it
              $new_Aface .= $index . ' ';
              $new_Bface->[8 + $fv_index] = $index;
              if (!defined($vertfaces->{$index})) {
                $vertfaces->{$index} = [];
              }
              $vertfaces->{$index} = [ @{$vertfaces->{$index}}, $face_index ];
              if ($use_tverts || $use_tverts1 || $use_tverts2 || $use_tverts3) {
                $tvertsi->{$index} = $index;
              }
              $match_found = 1;
              last;
            }
          }
          if ($match_found) {
            # match was found, proceed to next face vertex
            next;
          }
          # no match, use a new vertex
          my $new_index = scalar(@{$verts});
          # vertex position
          $verts->[$new_index] = [ @{$face_verts->[$fv_index]} ];
          # vertex texture UVs
          if ($use_tverts) {
            $tverts->[$new_index] = [ @{$face_tverts->[$fv_index]} ];
          }
          if ($use_tverts1) {
            $tverts1->[$new_index] = [ @{$face_tverts1->[$fv_index]} ];
          }
          if ($use_tverts2) {
            $tverts2->[$new_index] = [ @{$face_tverts2->[$fv_index]} ];
          }
          if ($use_tverts3) {
            $tverts3->[$new_index] = [ @{$face_tverts3->[$fv_index]} ];
          }
          if ($use_tverts || $use_tverts1 || $use_tverts2 || $use_tverts3) {
            $tvertsi->{$new_index} = $new_index;
          }
          # vertex smooth group (used for comparison only, not in MDX)
          $sgroups->[$new_index] = int($face->[3]);
          # vertex index in new face structure
          $new_Aface .= $new_index . ' ';
          $new_Bface->[8 + $fv_index] = $new_index;
          # update new map of vertex to connected face indices
          if (!defined($vertfaces->{$new_index})) {
            $vertfaces->{$new_index} = [];
          }
          $vertfaces->{$new_index} = [ @{$vertfaces->{$new_index}}, $face_index ];
          # vertex skin deformation data
          if ($use_skin) {
            $Abones->[$new_index] = $model{'nodes'}{$i}{Abones}[$face->[$fv_index]];
            $bones->[$new_index] = [ @{$model{'nodes'}{$i}{bones}[$face->[$fv_index]]} ];
            $weights->[$new_index] = [ @{$model{'nodes'}{$i}{weights}[$face->[$fv_index]]} ];
          }
        }
        # all vertices are now set for this face,
        # add the smoothgroup, tvert indices, and material ID
        $new_Aface = sprintf(
          '%s%s %s%s',
          $new_Aface,
          $face->[3],
          ($use_tverts || $use_tverts1 || $use_tverts2 || $use_tverts3)
            ? $new_Aface : '0 0 0 ',
          $face->[7]
        );
        # add the temporary face data to node's new faces structures
        $Afaces = [ @{$Afaces}, $new_Aface ];
        $Bfaces = [ @{$Bfaces}, $new_Bface ];
      }
      #print Dumper($verts);
      #print Dumper(@{$Bfaces});
      #print scalar(@{$verts}) . ' ' . scalar(@{$tverts}) . ' '. scalar(keys %{$tvertsi})."\n";
      # assign the new face and per-vertex data into original node.
      # we can assign because the loop will 'my' new references on the next iteration,
      # rather than reusing these references.
      # make sure all of the updated totals are stored!
      #XXX kill all use of precomputed totals eventually
      #$model{'nodes'}{$i}{Afaces} = [ @{$Afaces} ];
      #$model{'nodes'}{$i}{Bfaces} = [ @{$Bfaces} ];
      $model{'nodes'}{$i}{Afaces} = $Afaces;
      $model{'nodes'}{$i}{Bfaces} = $Bfaces;
      #$model{'nodes'}{$i}{verts} = [ @{$verts} ];
      $model{'nodes'}{$i}{verts} = $verts;
      $model{'nodes'}{$i}{vertnum} = scalar(@{$verts});
      #$model{'nodes'}{$i}{vertfaces} = { %{$vertfaces} };
      $model{'nodes'}{$i}{vertfaces} = $vertfaces;
      if ($use_tverts) {
        #$model{'nodes'}{$i}{tverts} = [ @{$tverts} ];
        $model{'nodes'}{$i}{tverts} = $tverts;
        $model{'nodes'}{$i}{tvertsnum} = scalar(@{$tverts});
      }
      if ($use_tverts1) {
        #$model{'nodes'}{$i}{tverts1} = [ @{$tverts1} ];
        $model{'nodes'}{$i}{tverts1} = $tverts1;
        $model{'nodes'}{$i}{tverts1num} = scalar(@{$tverts1});
      }
      if ($use_tverts2) {
        #$model{'nodes'}{$i}{tverts2} = [ @{$tverts2} ];
        $model{'nodes'}{$i}{tverts2} = $tverts2;
        $model{'nodes'}{$i}{tverts2num} = scalar(@{$tverts2});
      }
      if ($use_tverts3) {
        #$model{'nodes'}{$i}{tverts3} = [ @{$tverts3} ];
        $model{'nodes'}{$i}{tverts3} = $tverts3;
        $model{'nodes'}{$i}{tverts3num} = scalar(@{$tverts3});
      }
      if ($use_tverts || $use_tverts1 || $use_tverts2 || $use_tverts3) {
        #$model{'nodes'}{$i}{tverti} = { %{$tvertsi} };
        $model{'nodes'}{$i}{tverti} = $tvertsi;
        # remove the now-inaccurate list of uv indices per face
        delete $model{'nodes'}{$i}{'faceuvs'};
      }
      if ($use_skin) {
        #$model{'nodes'}{$i}{Abones} = [ @{$Abones} ];
        $model{'nodes'}{$i}{Abones} = $Abones;
        $model{'nodes'}{$i}{bones} = $bones;
        #$model{'nodes'}{$i}{weights} = [ @{$weights} ];
        $model{'nodes'}{$i}{weights} = $weights;
        $model{'nodes'}{$i}{weightsnum} = scalar(@{$weights});
      }
    }
  }


    # Define the hash (C Array?) to hold the normals,
    # As well as the hash for the surface areas
    # And the flattened vertex list

    my %faceareas    = ();
    my $face_by_pos  = {};


#    open LOG, ">", "log.txt";

    # compute what goes into the MDX data rows for this node, and the offsets for each type of data
    for (my $i = 0; $i < $nodenum; $i++)
    {
        $model{'nodes'}{$i}{'mdxdatasize'} = 0;
        $model{'nodes'}{$i}{'mdxrowoffsets'} = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1];
        # this is the right time to do any override tests for MDX contents
        if ($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_SABER) {
            # mesh of type lightsaber does not use MDX data, make sure size is 0 and offsets are -1
            # also clear the mdx data bitmap so everything is consistent
            $model{'nodes'}{$i}{'mdxdatabitmap'} = 0;
            next;
        }
        foreach (keys @{$structs{'mdxrows'}}) {
            if ($model{'nodes'}{$i}{'mdxdatabitmap'} & $structs{'mdxrows'}->[$_]{bitfield}) {
                # handle row offset in 2 ways, using same keys as readbinary, and a secondary method
                # using a combined array of the 11 possible offsets in common mesh header
                $model{'nodes'}{$i}{$structs{'mdxrows'}->[$_]{offset}} = $model{'nodes'}{$i}{'mdxdatasize'};
                $model{'nodes'}{$i}{'mdxrowoffsets'}->[$structs{'mdxrows'}->[$_]{offset_i}] = $model{'nodes'}{$i}{'mdxdatasize'};
                $model{'nodes'}{$i}{'mdxdatasize'} += $structs{'mdxrows'}->[$_]{num} * 4;
            } else {
                $model{'nodes'}{$i}{$structs{'mdxrows'}->[$_]{offset}} = -1;
            }
        }
        # add in the sub-type MDX row data
        if ($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_SKIN) {
            # add separate offsets for boneweights & boneindices, add their size to overall mdxdatasize
            $model{'nodes'}{$i}{'mdxboneweightsloc'} = $model{'nodes'}{$i}{'mdxdatasize'};
            $model{'nodes'}{$i}{'mdxdatasize'} += 4 * 4; # 4 4-byte floats
            $model{'nodes'}{$i}{'mdxboneindicesloc'} = $model{'nodes'}{$i}{'mdxdatasize'};
            $model{'nodes'}{$i}{'mdxdatasize'} += 4 * 4; # 4 4-byte floats
        }
        printf(
            "$i mdx bitmap %u size %u: offsets %s\n",
            $model{'nodes'}{$i}{'mdxdatabitmap'}, $model{'nodes'}{$i}{'mdxdatasize'},
            join(',', @{$model{'nodes'}{$i}{'mdxrowoffsets'}})
        ) if $printall;
    }

    # calculate new aabb trees if possible
    if (eval "use MDLOpsW; 1;")
    {
        # advanced walkmesh functions are available, build working aabb trees
        for (my $i = 0; $i < $model{'nodes'}{'truenodenum'}; $i++)
        {
            if (!($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_AABB)) {
                next;
            }
            # prepare enough walkmesh structure for the walkmesh aabb tree calculation
            $model{'nodes'}{$i}{'walkmesh'}{verts} = [
                @{$model{'nodes'}{$i}{'verts'}}
            ];
            $model{'nodes'}{$i}{'walkmesh'}{faces} = [
                map { [ @{$_}[8,9,10] ] } @{$model{'nodes'}{$i}{'Bfaces'}}
            ];
            # this is where the new aabb tree will be:
            $model{'nodes'}{$i}{'walkmesh'}{aabbs} = [];
            aabb(
                $model{'nodes'}{$i}{'walkmesh'},
                [ (0..(scalar(@{$model{'nodes'}{$i}{'walkmesh'}->{faces}}) - 1)) ]
            );
        }
    }

    # Convert smooth group numbers
    # Because we convert all smooth groups to 2^(n - 1), we should convert back here
    # Loop through all of the model's nodes
    for (my $i = 0; $i < $nodenum; $i++)
    {
      # Only look at smooth groups if this is a mesh w/ faces
      # If non-power-of-2 smooth groups were encountered in this mesh,
      # leave smooth group numbers alone
      if (!($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_MESH) ||
          !$model{'nodes'}{$i}{'sg_base2'} ||
          !defined($model{'nodes'}{$i}{'Afaces'}) ||
          !scalar(@{$model{'nodes'}{$i}{'Afaces'}})) {
        next;
      }
      # Process the smooth groups in the ASCII face data
      for my $f (@{$model{'nodes'}{$i}{'Afaces'}}) {
        my $temp = [ split /\s+/, $model{'nodes'}{$i}{'Afaces'}[$f] ];
        if ($temp->[3] < 1) {
          next;
        }
        $temp->[3] = (log($temp->[3]) / log(2)) + 1;
        $model{'nodes'}{$i}{'Afaces'}[$f] = join(' ', @{$temp});
      }
      # Process the smooth groups in the binary face data
      foreach (@{$model{'nodes'}{$i}{'Bfaces'}}) {
        my $sg = $_->[4];
        if ($sg < 1) {
          next;
        }
        $sg = (log($sg) / log(2)) + 1;
        $_->[4] = $sg;
      }
    }

    #$model{calculations} = {
    #  total_verts       => 0,
    #  total_vert_sum    => [ 0.0, 0.0, 0.0 ]
    #};
    #$model{'bmin'} = [ 0.0, 0.0, 0.0 ];
    #$model{'bmax'} = [ 0.0, 0.0, 0.0 ];
    for (my $i = 0; $i < $nodenum; $i ++)
    {
        # Skip non-mesh nodes
        if (!($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_MESH))
        {
            next;
        }
        my $vsum = [ 0.0, 0.0, 0.0 ];
        # note: changed these to 0 values on further study of vanilla models
        # it seems like bmin numbers should never be positive and
        # bmax numbers should never be negative
        $model{'nodes'}{$i}{'bboxmin'} = [ 0.0, 0.0, 0.0 ];
        $model{'nodes'}{$i}{'bboxmax'} = [ 0.0, 0.0, 0.0 ];
        for my $vert (@{$model{'nodes'}{$i}{'verts'}})
        {
            foreach (0..2)
            {
                if ($vert->[$_] < $model{'nodes'}{$i}{'bboxmin'}->[$_]) {
                    $model{'nodes'}{$i}{'bboxmin'}->[$_] = $vert->[$_];
                }
                if ($vert->[$_] > $model{'nodes'}{$i}{'bboxmax'}->[$_]) {
                #printf("%g > %g\n", $vert->[$_], $model{'nodes'}{$i}{'bboxmax'}->[$_]);
                    $model{'nodes'}{$i}{'bboxmax'}->[$_] = $vert->[$_];
                }
                $vsum->[$_] += $vert->[$_];
            }
        }
        $model{'nodes'}{$i}{'average'} = [
            map { $_ / scalar(@{$model{'nodes'}{$i}{'verts'}}) } @{$vsum}
        ];
        # yeaaaah ... it's a little tougher to compute the model bbox
        # we need to walk up the model node tree all the way to the root
        # in order to get an accurate position translation
        # compare our node bounding box against the running model bounding box
        #foreach (0..2)
        #{
            # translate node bbox to model coordinates for calculation
            #if (($model{'nodes'}{$i}{'bboxmin'}->[$_] +
            #     $model{'nodes'}{$i}{'position'}->[$_]) < $model{'bmin'}->[$_]) {
            #    $model{'bmin'}->[$_] = ($model{'nodes'}{$i}{'bboxmin'}->[$_] +
            #                            $model{'nodes'}{$i}{'position'}->[$_]);
            #}
            #if (($model{'nodes'}{$i}{'bboxmax'}->[$_] +
            #     $model{'nodes'}{$i}{'position'}->[$_]) > $model{'bmax'}->[$_]) {
            #    $model{'bmax'}->[$_] = ($model{'nodes'}{$i}{'bboxmax'}->[$_] +
            #                            $model{'nodes'}{$i}{'position'}->[$_]);
            #}
            #$model{calculations}->{total_vert_sum}[$_] += $vsum ->[$_];
        #}
        #$model{calculations}->{total_verts} += scalar(@{$model{'nodes'}{$i}{'verts'}});
        # compute node radius, it is the longest ray from average point to vertex
        $model{'nodes'}{$i}{'radius'} = 0.0;
        for my $vert (@{$model{'nodes'}{$i}{'verts'}}) {
            my $v_rad = [
                map { $vert->[$_] - $model{'nodes'}{$i}{'average'}->[$_] } (0..2)
            ];
            my $vec_len = sqrt($v_rad->[0]**2 + $v_rad->[1]**2 + $v_rad->[2]**2);
            if ($vec_len > $model{'nodes'}{$i}{'radius'}) {
                $model{'nodes'}{$i}{'radius'} = $vec_len;
            }
        }
    }

    # Compute model-global translations and vertex coordinates for each node
    for (my $i = 0; $i < $nodenum; $i++)
    {
        my $ancestry = [ $i ];
        my $parent = $model{'nodes'}{$i};
        # walk up to the root from the node, prepending each ancestor node number
        # so that we get a flat list of children from root to node
        while ($parent->{'parentnodenum'} != -1) {
            $ancestry = [ $parent->{'parentnodenum'}, @{$ancestry} ];
            $parent = $model{'nodes'}{$parent->{'parentnodenum'}};
        }
        # initialize the node's transform structure which contains
        # the model-global position and orientation, and,
        # a list of transformed vertex positions
        $model{'nodes'}{$i}{transform} = {
            position    => [ 0.0, 0.0, 0.0 ],
            orientation => [ 0.0, 0.0, 0.0, 1.0 ],
            verts       => []
        };
        for my $ancestor (@{$ancestry}) {
            #print Dumper($model{'nodes'}{$ancestor});
            #print Dumper($model{'nodes'}{$ancestor}{'Bcontrollers'});
            if (defined($model{'nodes'}{$ancestor}{'Bcontrollers'}) &&
                defined($model{'nodes'}{$ancestor}{'Bcontrollers'}{8})) {
                # node has a position, add it to current value
                map { $model{'nodes'}{$i}{transform}{position}->[$_] +=
                      $model{'nodes'}{$ancestor}{Bcontrollers}{8}{values}->[0][$_] } (0..2);
            }
            if (defined($model{'nodes'}{$ancestor}{'Bcontrollers'}) &&
                defined($model{'nodes'}{$ancestor}{'Bcontrollers'}{20})) {
                # node has an orientation, multiply quaternions to combine orientations
                $model{'nodes'}{$i}{transform}{orientation} = &quaternion_multiply(
                    $model{'nodes'}{$i}{transform}{orientation},
                    $model{'nodes'}{$ancestor}{'Bcontrollers'}{20}{values}->[0]
                );
            }
#            print Dumper($model{'nodes'}{$i}{transform});
        }
    }

    # Create a position-indexed structure containing all vertices in all meshes
    for (my $i = 0; $i < $nodenum; $i++)
    {
        if (!($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_MESH) ||
            ($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_SABER))
        {
            next;
        }
        # step through the vertices, storing the index in $work
        for $work (keys @{$model{'nodes'}{$i}{'verts'}})
        {
            # apply rotation to the vertex position
            my $vert_pos = &quaternion_apply($model{'nodes'}{$i}{transform}{orientation},
                                             $model{'nodes'}{$i}{'verts'}[$work]);
            # add position (this effectively makes the previous rotation around this point)
            $vert_pos = [
                map { $model{'nodes'}{$i}{transform}{position}->[$_] + $vert_pos->[$_] } (0..2)
            ];
            # store translated vertex position
            $model{'nodes'}{$i}{transform}{verts}->[$work] = $vert_pos;
            # generate string key based on translated vertex position
            my $vert_key = sprintf('%.4g,%.4g,%.4g', @{$vert_pos});
            if (!defined($face_by_pos->{$vert_key})) {
                $face_by_pos->{$vert_key} = [];
            }
            # append this vertex's data to the data list for this position
            $face_by_pos->{$vert_key} = [
                @{$face_by_pos->{$vert_key}},
                {
                    mesh  => $i,
                    meshname => $model{partnames}[$i],
                    faces => [ @{$model{'nodes'}{$i}{'vertfaces'}{$work}} ],
                    vertex => $work
                }
            ];
        }
    }

    # Total surface area for each smooth group defined in the model,
    # smooth groups can be used as cross-mesh objects,
    # so we don't want this structure to be under a specific node
    $model{'surfacearea_by_group'} = {};

    # Calculate face surface areas and record surface area totals
    # Loop through all of the model's nodes
    for (my $i = 0; $i < $nodenum; $i ++)
    {
        # these calculations are only for mesh nodes
        if (!($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_MESH)) {
            # skip non-mesh nodes
            next;
        }

        # initialize new value for total surface area of faces in this mesh
        $model{'nodes'}{$i}{'surfacearea'} = 0;
        # initialize new hash for total surface areas of faces in this mesh,
        # per smooth-group (this is recorded but unused so far)
        $model{'nodes'}{$i}{'surfacearea_by_group'} = {};

        # Loop through all the node's faces
        foreach (keys @{$model{'nodes'}{$i}{'Bfaces'}}) {
            # store the face data in a hash reference, $face
            my $face = $model{'nodes'}{$i}{'Bfaces'}->[$_];
            # store the triangular face's 3 vertices as list references in $v1-3
            my ($v1, $v2, $v3) = (
                $model{'nodes'}{$i}{'verts'}[$face->[8]],
                $model{'nodes'}{$i}{'verts'}[$face->[9]],
                $model{'nodes'}{$i}{'verts'}[$face->[10]]
            );

            # calculate the face's surface area
            my ($a, $b, $c, $s) = (0, 0, 0, 0);
            $a = sqrt(($v1->[0] - $v2->[0]) ** 2 +
                      ($v1->[1] - $v2->[1]) ** 2 +
                      ($v1->[2] - $v2->[2]) ** 2);

            $b = sqrt(($v1->[0] - $v3->[0]) ** 2 +
                      ($v1->[1] - $v3->[1]) ** 2 +
                      ($v1->[2] - $v3->[2]) ** 2);

            $c = sqrt(($v2->[0] - $v3->[0]) ** 2 +
                      ($v2->[1] - $v3->[1]) ** 2 +
                      ($v2->[2] - $v3->[2]) ** 2);

            $s = ($a + $b + $c)/2;
            my $area = sqrt($s * ($s - $a) * ($s - $b) * ($s - $c));

            #print "Area: $area in $face->[4]\n";

            # record the face area in the faceareas hash
            $faceareas{$i}{$_} = $area;

            # update the node-level total surface area, this might be a mesh header field
            $model{'nodes'}{$i}{'surfacearea'} += $area;

            # initialize node-level smoothgroup surface area to 0 if first face in group
            if (!defined($model{'nodes'}{$i}{'surfacearea_by_group'}->{$face->[4]})) {
                $model{'nodes'}{$i}{'surfacearea_by_group'}->{$face->[4]} = 0;
            }
            # increase node-level total surface area for smoothgroup
            $model{'nodes'}{$i}{'surfacearea_by_group'}->{$face->[4]} += $area;

            # initialize total surface area for smoothgroup to 0 if first face in group
            if (!defined($model{'surfacearea_by_group'}->{$face->[4]})) {
                $model{'surfacearea_by_group'}->{$face->[4]} = 0;
            }
            # increase total surface area for smoothgroup
            $model{'surfacearea_by_group'}->{$face->[4]} += $area;
        }
    }

    # Calculate face surface normals
    # Calculate face tangent and bitangent vectors if bumpmapping
    # Loop through all of the model's nodes
    for (my $i = 0; $i < $nodenum; $i ++)
    {
        # these calculations are only for mesh nodes
        if (!($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_MESH) ||
            ($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_SABER)) {
            # skip non-mesh nodes
            # skip saber mesh nodes
            next;
        }

        # If the node has a mesh and isn't a saber, calculate the face plane normals and plane distances
        if (($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_MESH) && !($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_SABER))
        {
            print ("calculating plane normals for node $i\n") if $printall;

            $count = 0; 

            # Loop through each of the node's faces and calculate the normals
            foreach (@{$model{'nodes'}{$i}{'Bfaces'}})
            {
                my ($p1x, $p1y, $p1z, $p2x, $p2y, $p2z, $p3x, $p3y, $p3z);
                my ($xpx, $xpy, $xpz, $pd, $norm);

                $p1x = $model{'nodes'}{$i}{'verts'}[$_->[8]][0];  # Vertex 1's X
                $p1y = $model{'nodes'}{$i}{'verts'}[$_->[8]][1];  # Vertex 1's Y
                $p1z = $model{'nodes'}{$i}{'verts'}[$_->[8]][2];  # Vertex 1's Z

                $p2x = $model{'nodes'}{$i}{'verts'}[$_->[9]][0];  # Vertex 2's X
                $p2y = $model{'nodes'}{$i}{'verts'}[$_->[9]][1];  # Vertex 2's Y
                $p2z = $model{'nodes'}{$i}{'verts'}[$_->[9]][2];  # Vertex 2's Z

                $p3x = $model{'nodes'}{$i}{'verts'}[$_->[10]][0]; # Vertex 3's X
                $p3y = $model{'nodes'}{$i}{'verts'}[$_->[10]][1]; # Vertex 3's Y
                $p3z = $model{'nodes'}{$i}{'verts'}[$_->[10]][2]; # Vertex 3's Z

                # Old MDLOps code
                #calculate the un-normalized cross product and un-normalized plane distance
                $xpx = $p1y * ($p2z - $p3z) + $p2y * ($p3z - $p1z) + $p3y * ($p1z - $p2z);
                $xpy = $p1z * ($p2x - $p3x) + $p2z * ($p3x - $p1x) + $p3z * ($p1x - $p2x);
                $xpz = $p1x * ($p2y - $p3y) + $p2x * ($p3y - $p1y) + $p3x * ($p1y - $p2y);
                $pd  = -$p1x * ($p2y * $p3z - $p3y * $p2z) - $p2x * ($p3y * $p1z - $p1y * $p3z) - $p3x * ($p1y * $p2z - $p2y * $p1z);


                #calculate the normalizing factor
                $norm = sqrt($xpx**2 + $xpy**2 + $xpz**2);

#               print "Normalizing calculated: $norm\n";

                # Check for $norm being 0 to prevent illegal division by 0...
                $model{'nodes'}{$i}{'facenormals'}[$count] = normalize_vector([ $xpx, $xpy, $xpz ]);

                if ($norm != 0)
                {
                    # also normalize the plane distance, critical for aabb
                    # not really normalization, just pretending to have been constructed from
                    # normalized vectors
                    $pd /= $norm;
                } else {
                    print("Overlapping vertices in node: $model{'partnames'}[$i]\n");
                    print("x: $p1x, y: $p1y, z: $p1z\n");
                    print("x: $p2x, y: $p2y, z: $p2z\n");
                    print("x: $p3x, y: $p3y, z: $p3z\n");
                }
                # store the normalized values;
                $_->[0] = $model{'nodes'}{$i}{'facenormals'}[$count][0];
                $_->[1] = $model{'nodes'}{$i}{'facenormals'}[$count][1];
                $_->[2] = $model{'nodes'}{$i}{'facenormals'}[$count][2];
                $_->[3] = $pd;
#                if($i == 87) { print LOG "Normals for Face $count: " . $Nx/$norm . " " . $Ny/$norm . " " . $Nz/$norm . "\n"; }

                $count++;
#                print "Count increasing\n";

                # print ("$i " . $_->[0] . " " . $_->[1] . " " . $_->[2] . " " . $_->[3] . "\n");

                # determine whether this node uses normal/bump mapping requiring tangent space calculations
                if ($model{'nodes'}{$i}{'bitmap'} =~ /null/i ||
                    !($model{'nodes'}{$i}{'mdxdatabitmap'} & MDX_TANGENT_SPACE)) {
                    # skip tangent/bitangent calculations for non-bump-mapped textures
                    next;
                }
                # compute face tangent and bitangent vectors for bump-mapped textures
                # based on (with key differences for what bioware wants) technique from:
                # http://www.opengl-tutorial.org/intermediate-tutorials/tutorial-13-normal-mapping/
                my ($v0, $v1, $v2) = (
                    $model{'nodes'}{$i}{'verts'}[$_->[8]],
                    $model{'nodes'}{$i}{'verts'}[$_->[9]],
                    $model{'nodes'}{$i}{'verts'}[$_->[10]]
                );
                my ($uv0, $uv1, $uv2) = (
                    $model{'nodes'}{$i}{'tverts'}[$model{'nodes'}{$i}{'tverti'}{$_->[8]}],
                    $model{'nodes'}{$i}{'tverts'}[$model{'nodes'}{$i}{'tverti'}{$_->[9]}],
                    $model{'nodes'}{$i}{'tverts'}[$model{'nodes'}{$i}{'tverti'}{$_->[10]}]
                );
                my ($deltaPos1, $deltaPos2, $deltaUV1, $deltaUV2);
                $deltaPos1 = [ $v1->[0] - $v0->[0], $v1->[1] - $v0->[1], $v1->[2] - $v0->[2] ];
                $deltaPos2 = [ $v2->[0] - $v0->[0], $v2->[1] - $v0->[1], $v2->[2] - $v0->[2] ];
                $deltaUV1  = [ $uv1->[0] - $uv0->[0], $uv1->[1] - $uv0->[1] ];
                $deltaUV2  = [ $uv2->[0] - $uv0->[0], $uv2->[1] - $uv0->[1] ];
                # this is the texture normal's Z component, used to detect texture mirroring
                # it was originally a = uv0 - uv1, b = uv2 - uv1, N=cross(a,b),
                # but since we're talking about a 2d triangle, there's never any XY vector component,
                # so it reduces to just calculating the Z (or w) component of the cross product
                my $tNz = (
                    ($uv0->[0] - $uv1->[0]) * ($uv2->[1] - $uv1->[1]) -
                    ($uv0->[1] - $uv1->[1]) * ($uv2->[0] - $uv1->[0])
                );

                my $r = ($deltaUV1->[0] * $deltaUV2->[1] - $deltaUV1->[1] * $deltaUV2->[0]);
                if ($r == 0.000000) {
                    # prevent a divide-by-zero, this doesn't usually happen for actually-textured objects
                    printf("Overlapping texture vertices in node: %s\n" .
                           "x: % .7g, y: % .7g\nx: % .7g, y: % .7g\nx: % .7g, y: % .7g\n",
                           $model{'partnames'}[$i], @{$uv0}, @{$uv1}, @{$uv2});
                    # this is a weird magic factor determined algebraically from analyzing how p_g0t0.mdl copes
                    # with all the overlapping tex vertices
                    $r = 2406.6388;
                } else {
                    $r = 1.0 / $r;
                }
                # compute face tangent vector
                my $tangent = [
                    ($deltaPos1->[0] * $deltaUV2->[1] - $deltaPos2->[0] * $deltaUV1->[1]) * $r,
                    ($deltaPos1->[1] * $deltaUV2->[1] - $deltaPos2->[1] * $deltaUV1->[1]) * $r,
                    ($deltaPos1->[2] * $deltaUV2->[1] - $deltaPos2->[2] * $deltaUV1->[1]) * $r
                ];
                # compute normalizing factor for tangent vector
                my $bnormalizing_factor = sqrt(
                    ($tangent->[0] ** 2) +
                    ($tangent->[1] ** 2) +
                    ($tangent->[2] ** 2)
                );
                # normalize the face tangent vector by applying the computed factor
                if ($bnormalizing_factor) {
                    # divide each component by normalizing factor
                    $tangent = [
                        map { $_ / $bnormalizing_factor } @{$tangent}
                    ];
                }
                # fix 0-vectors arising from overlapping texture vertices
                if ($tangent->[0] == 0.0000 && $tangent->[1] == 0.0000 && $tangent->[2] == 0.0000) {
                    # it seems incredibly unlikely that these should both just be set to 1,0,0 unconditionally.
                    # my guess here is that there is some criteria for determining whether X,Y, or Z should be 1
                    $tangent = [ 1.0, 0.0, 0.0 ];
                }
                $model{'nodes'}{$i}{'facetangents'}[$count - 1] = $tangent;

                # compute face bitangent vector
                my $bitangent = [
                    ($deltaPos2->[0] * $deltaUV1->[0] - $deltaPos1->[0] * $deltaUV2->[0]) * $r,
                    ($deltaPos2->[1] * $deltaUV1->[0] - $deltaPos1->[1] * $deltaUV2->[0]) * $r,
                    ($deltaPos2->[2] * $deltaUV1->[0] - $deltaPos1->[2] * $deltaUV2->[0]) * $r
                ];
                # compute normalizing factor for bitangent vector
                my $bnormalizing_factor = sqrt(
                    ($bitangent->[0] ** 2) +
                    ($bitangent->[1] ** 2) +
                    ($bitangent->[2] ** 2)
                );
                # normalize the face bitangent vector by applying the computed factor
                if ($bnormalizing_factor) {
                    # divide each component by normalizing factor
                    $bitangent = [
                        map { $_ / $bnormalizing_factor } @{$bitangent}
                    ];
                }
                # fix 0-vectors arising from overlapping texture vertices
                if ($bitangent->[0] == 0.0000 && $bitangent->[1] == 0.0000 && $bitangent->[2] == 0.0000) {
                    # it seems incredibly unlikely that these should both just be set to 1,0,0 unconditionally.
                    # my guess here is that there is some criteria for determining whether X,Y, or Z should be 1
                    $bitangent = [ 1.0, 0.0, 0.0 ];
                }
                $model{'nodes'}{$i}{'facebitangents'}[$count - 1] = $bitangent;

                # fix tangent space handedness: make this true: dot(cross(n,t),b) < 0
                # the game seems to want TBN NOT to form a right-handed coordinate system
                # or, cross(n,t) must have a different orientation from vector b
                my $cross_nt = [
                    $model{'nodes'}{$i}{'facenormals'}[$count - 1][1] * $model{'nodes'}{$i}{'facetangents'}[$count - 1]->[2] -
                    $model{'nodes'}{$i}{'facenormals'}[$count - 1][2] * $model{'nodes'}{$i}{'facetangents'}[$count - 1]->[1],
                    $model{'nodes'}{$i}{'facenormals'}[$count - 1][2] * $model{'nodes'}{$i}{'facetangents'}[$count - 1]->[0] -
                    $model{'nodes'}{$i}{'facenormals'}[$count - 1][0] * $model{'nodes'}{$i}{'facetangents'}[$count - 1]->[2],
                    $model{'nodes'}{$i}{'facenormals'}[$count - 1][0] * $model{'nodes'}{$i}{'facetangents'}[$count - 1]->[1] -
                    $model{'nodes'}{$i}{'facenormals'}[$count - 1][1] * $model{'nodes'}{$i}{'facetangents'}[$count - 1]->[0]
                ];
                if (($cross_nt->[0] * $model{'nodes'}{$i}{'facebitangents'}[$count - 1]->[0] +
                     $cross_nt->[1] * $model{'nodes'}{$i}{'facebitangents'}[$count - 1]->[1] +
                     $cross_nt->[2] * $model{'nodes'}{$i}{'facebitangents'}[$count - 1]->[2]) > 0.0) {
                    $model{'nodes'}{$i}{'facetangents'}[$count - 1] = [
                        map { $_ * -1.0 } @{$model{'nodes'}{$i}{'facetangents'}[$count - 1]}
                    ];
                }
                # if texture is mirrored, we need to invert both tangent and bitangent now
                if ($tNz > 0.0) {
                    $model{'nodes'}{$i}{'facetangents'}[$count - 1] = [
                        map { $_ * -1.0 } @{$model{'nodes'}{$i}{'facetangents'}[$count - 1]}
                    ];
                    $model{'nodes'}{$i}{'facebitangents'}[$count - 1] = [
                        map { $_ * -1.0 } @{$model{'nodes'}{$i}{'facebitangents'}[$count - 1]}
                    ];
                }
                #XXX there is some condition where the tangent space vertex normals differ greatly from the usual vertex normals,
                # it seems to have something to do with the overlapping texture vertex situation, but i'm not sure how yet.
            }
        }
    }

    # Calculate vertex normals and tangent space basis
    # Loop through all of the model's nodes
    for (my $i = 0; $i < $nodenum; $i ++)
    {

        # these calculations are only for mesh nodes
        if (!($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_MESH) ||
            ($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_SABER)) {
            # skip non-mesh nodes
            # skip saber mesh nodes
            next;
        }

#        print $i . ' ' . scalar @{$model{'nodes'}{$i}{'Bfaces'}} . "\n";
#        print LOG "\n";

        # step through the vertices in this mesh
        foreach $work (keys @{$model{'nodes'}{$i}{'verts'}})
        {
            my $vert_key = sprintf(
                '%.4g,%.4g,%.4g',
                @{$model{'nodes'}{$i}{transform}{verts}->[$work]}
            );
            my $position_data = [ @{$face_by_pos->{$vert_key}} ];
            my $meshA = $i;
            my $faceA = -1;
            my $sgA   = -1;
            for my $pos_data (@{$position_data}) {
                if ($pos_data->{mesh} == $i && $pos_data->{vertex} == $work) {
                    # found match
                    if (scalar(@{$pos_data->{faces}})) {
                        $faceA = $pos_data->{faces}[0];
                        if ($meshA == 62) {
                          #printf("vert:%u faceA:%u\n", $work, $faceA);
                        }
                    }
                }
            }
            if ($faceA == -1) {
                $model{'nodes'}{$i}{'vertexnormals'}{$work} = [ 1, 0, 0 ];
                next;
            }
            $sgA = $model{'nodes'}{$i}{'Bfaces'}[$faceA]->[4];
            my $weight_factor = $faceareas{$meshA}{$faceA};
            my ($av1, $av2, $av3) = (
                $model{'nodes'}{$meshA}{'verts'}[$model{'nodes'}{$meshA}{'Bfaces'}[$faceA]->[8]],
                $model{'nodes'}{$meshA}{'verts'}[$model{'nodes'}{$meshA}{'Bfaces'}[$faceA]->[9]],
                $model{'nodes'}{$meshA}{'verts'}[$model{'nodes'}{$meshA}{'Bfaces'}[$faceA]->[10]]
            );
            if (vertex_equals($model{'nodes'}{$i}{'verts'}[$work], $av1))
            {
                $weight_factor *= compute_vertex_angle($av1, $av2, $av3);
            }
            elsif (vertex_equals($model{'nodes'}{$i}{'verts'}[$work], $av2))
            {
                $weight_factor *= compute_vertex_angle($av2, $av1, $av3);
            }
            elsif (vertex_equals($model{'nodes'}{$i}{'verts'}[$work], $av3))
            {
                $weight_factor *= compute_vertex_angle($av3, $av1, $av2);
            }
            if (!$options->{use_weights}) {
                $weight_factor = 1;
            }
            if ($options->{use_weights} &&
                $model{'nodes'}{$i}{'nodetype'} & NODE_HAS_AABB) {
              # not using angle weight for aabb vertex normals
              $weight_factor = $faceareas{$meshA}{$faceA};
            }
            $model{'nodes'}{$i}{'vertexnormals'}{$work} = [
                map { $_ * $weight_factor } @{$model{'nodes'}{$meshA}{'facenormals'}[$faceA]}
            ];
            # initialize tangent space vectors with value from chosen face vectors
            if (defined($model{'nodes'}{$meshA}{'facetangents'}) &&
                defined($model{'nodes'}{$meshA}{'facetangents'}[$faceA])) {
                $model{'nodes'}{$i}{'vertextangents'}[$work] = [
                    map { $_ * $weight_factor } @{$model{'nodes'}{$meshA}{'facetangents'}[$faceA]}
                ];
                $model{'nodes'}{$i}{'vertexbitangents'}[$work] = [
                    map { $_ * $weight_factor } @{$model{'nodes'}{$meshA}{'facebitangents'}[$faceA]}
                ];
                # this is where we store the final numbers, store them now in case the calculations get skipped
                $model{'nodes'}{$i}{'Btangentspace'}[$work] = [
                    @{$model{'nodes'}{$i}{'vertexbitangents'}[$work]},
                    @{$model{'nodes'}{$i}{'vertextangents'}[$work]},
                    @{$model{'nodes'}{$i}{'vertexnormals'}{$work}}
                ];
            }
            for my $pos_data (@{$position_data}) {
                my $meshB = $pos_data->{mesh};
                for my $faceB (@{$pos_data->{faces}}) {
                    # skip self (test face index and node index!)
                    if ($meshB == $meshA && $faceB == $faceA) {
                        $printall and print "skip self\n";
                        next;
                    }
                    # don't let rendering geometry influence non-rendering, and vice versa
                    if ($model{'nodes'}{$meshA}{'render'} != $model{'nodes'}{$meshB}{'render'}) {
                        $printall and print "skip visibility mismatch\n";
                        next;
                    }
                    if (($model{'nodes'}{$meshA}{'nodetype'} & NODE_HAS_AABB) &&
                        $meshA != $meshB) {
                        # prevent cross-mesh vertex normal accumulation for AABB nodes
                        $printall and printf(
                            "skip non-AABB for vertex normals in AABB %s %s\n",
                            $model{partnames}[$meshA], $model{partnames}[$meshB]
                        );
                        next;
                    }
                    # don't let influence of geometry from different smooth groups accumulate into the vertex normal
                    # TODO resolve smooth group numbers vs. surface IDs...
                    if (!($model{'nodes'}{$meshB}{'Bfaces'}[$faceB]->[4] & $sgA)) {
                        $printall and printf("skip sg %u != %u\n", $model{'nodes'}{$meshB}{'Bfaces'}[$faceB]->[4], $sgA);
                        next;
                    }
                    if ($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_MESH &&
                        $options->{use_crease_angle} &&
                        compute_vector_angle($model{'nodes'}{$meshA}{'facenormals'}[$faceA],
                                             $model{'nodes'}{$meshB}{'facenormals'}[$faceB], 0) > $options->{crease_angle}) {
#                      acos($model{'nodes'}{$meshA}{'facenormals'}[$faceA]->[0] *
#                           $model{'nodes'}{$meshB}{'facenormals'}[$faceB]->[0] +
#                           $model{'nodes'}{$meshA}{'facenormals'}[$faceA]->[1] *
#                           $model{'nodes'}{$meshB}{'facenormals'}[$faceB]->[1] +
#                           $model{'nodes'}{$meshA}{'facenormals'}[$faceA]->[2] *
#                           $model{'nodes'}{$meshB}{'facenormals'}[$faceB]->[2]) > pi / 3){
                        if ($model{'nodes'}{$meshA}{'render'}) {
                        # it is not at all clear what this should be yet
                            $printall and printf(
                                "skipped %s accumulation \@%.4g,%.4g,%.4g with crease angle: % .7g\n",
                                $model{'partnames'}[$meshA], @{$model{'nodes'}{$i}{'verts'}[$work]},
                                compute_vector_angle($model{'nodes'}{$meshA}{'facenormals'}[$faceA],
                                                     $model{'nodes'}{$meshB}{'facenormals'}[$faceB], 0)
                            );
                        }
                        #next;
                    }
                    my $area = $faceareas{$meshB}{$faceB};
                    # initialize angle to 1 in case no vertices match somehow
                    my $angle = -1;
                    # store faceB vertices in listrefs $bv1-3
                    my ($bv1, $bv2, $bv3) = (
                        $model{'nodes'}{$meshB}{'verts'}[$model{'nodes'}{$meshB}{'Bfaces'}[$faceB]->[8]],
                        $model{'nodes'}{$meshB}{'verts'}[$model{'nodes'}{$meshB}{'Bfaces'}[$faceB]->[9]],
                        $model{'nodes'}{$meshB}{'verts'}[$model{'nodes'}{$meshB}{'Bfaces'}[$faceB]->[10]]
                    );
                    if (vertex_equals($model{'nodes'}{$i}{'verts'}[$work], $bv1, 4))
                    {
                        $angle = compute_vertex_angle($bv1, $bv2, $bv3);
                    }
                    elsif (vertex_equals($model{'nodes'}{$i}{'verts'}[$work], $bv2, 4))
                    {
                        $angle = compute_vertex_angle($bv2, $bv1, $bv3);
                    }
                    elsif (vertex_equals($model{'nodes'}{$i}{'verts'}[$work], $bv3, 4))
                    {
                        $angle = compute_vertex_angle($bv3, $bv1, $bv2);
                    }
                    if ($options->{use_weights} && $angle == -1) {
                        # if angle does not get computed, this is usually a miss
                        # due to vertex comparison precision. in a perfect world
                        # we would lower precision and retry.
                        printf "skip %u bad %u face: %u\n", $meshA, $meshB, $faceB;
                        next;
                    }
                    # honor the use_weights boolean to override weights calculations
                    # to 1 & 1 until they can be verified correct
                    if (!$options->{use_weights}) {
                        $area = 1;
                        $angle = 1;
                    }
                    if ($model{'nodes'}{$meshA}{'nodetype'} & NODE_HAS_AABB) {
                        # never use angle weighted calculation for aabb...
                        $angle = 1;
                    }
                    # apply angle & area weight to faceB surface normal and
                    # accumulate the x, y, and z components of the vertex normal vector
                    $model{'nodes'}{$i}{'vertexnormals'}{$work}->[0] += (
                        $model{'nodes'}{$meshB}{'facenormals'}[$faceB]->[0] * $area * $angle
                    );
                    $model{'nodes'}{$i}{'vertexnormals'}{$work}->[1] += (
                        $model{'nodes'}{$meshB}{'facenormals'}[$faceB]->[1] * $area * $angle
                    );
                    $model{'nodes'}{$i}{'vertexnormals'}{$work}->[2] += (
                        $model{'nodes'}{$meshB}{'facenormals'}[$faceB]->[2] * $area * $angle
                    );
                    # accumulate the x, y, and z components of the face tangent and bitangent vectors for tangent space
                    if (defined($model{'nodes'}{$meshB}{'facetangents'}[$faceB])) {
                        $model{'nodes'}{$i}{'vertextangents'}[$work]->[0] += (
                            $model{'nodes'}{$meshB}{'facetangents'}[$faceB]->[0] * $area * $angle
                        );
                        $model{'nodes'}{$i}{'vertextangents'}[$work]->[1] += (
                            $model{'nodes'}{$meshB}{'facetangents'}[$faceB]->[1] * $area * $angle
                        );
                        $model{'nodes'}{$i}{'vertextangents'}[$work]->[2] += (
                            $model{'nodes'}{$meshB}{'facetangents'}[$faceB]->[2] * $area * $angle
                        );
                        $model{'nodes'}{$i}{'vertexbitangents'}[$work]->[0] += (
                            $model{'nodes'}{$meshB}{'facebitangents'}[$faceB]->[0] * $area * $angle
                        );
                        $model{'nodes'}{$i}{'vertexbitangents'}[$work]->[1] += (
                            $model{'nodes'}{$meshB}{'facebitangents'}[$faceB]->[1] * $area * $angle
                        );
                        $model{'nodes'}{$i}{'vertexbitangents'}[$work]->[2] += (
                            $model{'nodes'}{$meshB}{'facebitangents'}[$faceB]->[2] * $area * $angle
                        );
                    }
                }
            }
            # vertex normals are now computed, normalize the vector and store
            $model{'nodes'}{$i}{'vertexnormals'}{$work} = normalize_vector(
                $model{'nodes'}{$i}{'vertexnormals'}{$work}
            );
            if (defined($model{'nodes'}{$i}{'vertextangents'}) &&
                defined($model{'nodes'}{$i}{'vertextangents'}[$work])) {
                # construct the MDX-ready representation of the tangent space data
                $model{'nodes'}{$i}{'Btangentspace'}[$work] = [
                    @{normalize_vector($model{'nodes'}{$i}{'vertexbitangents'}[$work])},
                    @{normalize_vector($model{'nodes'}{$i}{'vertextangents'}[$work])},
                    @{$model{'nodes'}{$i}{'vertexnormals'}{$work}}
                ];
            }
        }
        if ($printall && defined($model{'nodes'}{$i}{'vertextangents'})) {
            foreach (keys @{$model{'nodes'}{$i}{'vertextangents'}}) {
                printf("$i %u (%.7f, %.7f, %.7f) (%.7f, %.7f, %.7f) (%.7f, %.7f, %.7f)\n",
                       $_,
                       @{$model{'nodes'}{$i}{'Btangentspace'}[$_]});
                       #@{$model{'nodes'}{$i}{'vertexbitangents'}[$_]},
                       #@{$model{'nodes'}{$i}{'vertextangents'}[$_]},
                       #@{$model{'nodes'}{$i}{'vertexnormals'}{$_}});
            }
        }
    }

    # Calculate adjacent faces using the face-by-position map
    # Loop through all of the model's nodes
    for (my $i = 0; $i < $nodenum; $i ++)
    {
        # these calculations are only for mesh nodes
        if (!($model{'nodes'}{$i}{'nodetype'} & NODE_HAS_MESH)) {
            # skip non-mesh nodes
            next;
        }
        my $results = {};
        my $consider_all = 1;
        # step through all faces for this node, store face index in $j
        for my $j (keys @{$model{'nodes'}{$i}{'Bfaces'}})
        {
            # get the position data for each of face $j's 3 vertex positions
            my $position_data = [
                $face_by_pos->{sprintf('%.4g,%.4g,%.4g', @{
                    $model{'nodes'}{$i}{transform}{verts}->[$model{'nodes'}{$i}{'Bfaces'}[$j][8]]
                })},
                $face_by_pos->{sprintf('%.4g,%.4g,%.4g', @{
                    $model{'nodes'}{$i}{transform}{verts}->[$model{'nodes'}{$i}{'Bfaces'}[$j][9]]
                })},
                $face_by_pos->{sprintf('%.4g,%.4g,%.4g', @{
                    $model{'nodes'}{$i}{transform}{verts}->[$model{'nodes'}{$i}{'Bfaces'}[$j][10]]
                })},
            ];
#printf(
#"(%.4g,%.4g,%.4g),(%.4g,%.4g,%.4g),(%.4g,%.4g,%.4g)\n",
#@{$model{'nodes'}{$i}{transform}{verts}->[$model{'nodes'}{$i}{'Bfaces'}[$j][8]]},
#@{$model{'nodes'}{$i}{transform}{verts}->[$model{'nodes'}{$i}{'Bfaces'}[$j][9]]},
#@{$model{'nodes'}{$i}{transform}{verts}->[$model{'nodes'}{$i}{'Bfaces'}[$j][10]]},
#);
#print Dumper($position_data);
            # place vertface maps for each of face $j's 3 vertices into $vfs listref
            my $vfs = [ [], [], [] ];
            for my $facevert (0..2) {
                for my $pos_data (@{$position_data->[$facevert]}) {
                    if ($pos_data->{mesh} == $i &&
                        $pos_data->{vertex} == $model{'nodes'}{$i}{'Bfaces'}[$j][8 + $facevert]) {
                        # the connected faces for this vert
                        $vfs->[$facevert] = [ @{$vfs->[$facevert]}, @{$pos_data->{faces}} ];
                        last;
                    }
                }
                if ($consider_all) {
                    for my $pos_data (@{$position_data->[$facevert]}) {
                        if ($pos_data->{mesh} == $i &&
                            $pos_data->{vertex} != $model{'nodes'}{$i}{'Bfaces'}[$j][8 + $facevert]) {
                            # the connected faces for this vert
                            $vfs->[$facevert] = [ @{$vfs->[$facevert]}, @{$pos_data->{faces}} ];
                        }
                    }
                }
            }
            # we know that vfs[0] has all faces adjacent to 1,
            # vfs[1] all adjacent to 2, vfs[2] all adjacent to 3
            # initialize matches hash with one hash per face vertex
            my $matches = {
                0 => { map { $_ => 1 } grep { $_ != $j } @{$vfs->[0]} },
                1 => { map { $_ => 1 } grep { $_ != $j } @{$vfs->[1]} },
                2 => { map { $_ => 1 } grep { $_ != $j } @{$vfs->[2]} }
            };
            # step through 0,1,2 for 3 vertices of face $j
            for my $l (0..2) {
                # step through all faces adjacent to vertex $l
                foreach(keys %{$matches->{$l}}) {
                    # testing for 2 vertex match (aka, an edge match)
                    # so use $l and $l + 1, unless we are on 2,
                    # when we use $l and $l - 2.
                    my $next = $l == 2 ? -2 : 1;
                    # if $l + $next entry is set, we have found an edge,
                    # and this is an adjacent face, record it in results
                    if ($matches->{$l + $next}{$_}) {
                        $results->{$j}[$l] = $_;
                    }
                }
                if ((defined($results->{$j}[$l]) &&
                     $results->{$j}[$l] != $model{'nodes'}{$i}{'Bfaces'}[$j][5 + $l]) ||
                    (!defined($results->{$j}[$l]) &&
                     $model{'nodes'}{$i}{'Bfaces'}[$j][5 + $l] != -1)) {
                    # this block was for testing against the old method's results
                    # testing showed that the new method works better, because
                    # it has a better understanding of overlapping geometry
                    # (the old method required exact matches, the new uses a set tolerance)
#printf( "mismatch %s $j $l\n", $model{'partnames'}[$i] );
#print Dumper($model{'nodes'}{$i}{'Bfaces'}[$j]);
#print Dumper($results->{$j});
#print Dumper($vfs);
#print Dumper($matches);
                }
                # record the adjacent face result in Bfaces entry
                if (defined($results->{$j}[$l])) {
                    $model{'nodes'}{$i}{'Bfaces'}[$j][5 + $l] = $results->{$j}[$l];
                }
            }
            delete $results->{$j};
        }
    }

#    close LOG;

  # post-process the geometry nodes
  postprocessnodes($model{'nodes'}{0}, \%model, 0);
  # post-process the animation nodes
  for (my $i = 0; $i < $model{'numanims'}; $i++) {
    # need to pass in model{anims}{i} instead of \%model in order to keep
    # the post processing happening on animation node entries instead of geometry
    # when it recurses
    postprocessnodes($model{'anims'}{$i}{'nodes'}{0}, $model{'anims'}{$i}, 1);
  }
  
  print (" nodenum: " . $nodenum . " true: " . $model{'nodes'}{'truenodenum'} . "\n") if $printall;
  $nodenum = $model{'nodes'}{'truenodenum'};
  #cook the bone weights and prepare the bone map
  for (my $i = 0; $i < $nodenum; $i++) {
    $work = 0;
    if ($model{'nodes'}{$i}{'nodetype'} == NODE_SKIN) {
      #fill the bone map with -1
      for (my $j = 0; $j < $nodenum; $j++) {
        $model{'nodes'}{$i}{'node2index'}[$j] = -1;
      }
      # loop through the bones+weights
      for (my $j = 0; $j < $model{'nodes'}{$i}{'weightsnum'}; $j++) {
        #print( " $#{$model{'nodes'}{$i}{'bones'}[$j]} \n");
        $temp1 = "";
        $temp2 = "";
        for (my $k = 0; $k < 4; $k++) {
          if ($model{'nodes'}{$i}{'bones'}[$j][$k] ne "") {
            if ($model{'nodes'}{$i}{'node2index'}[$nodeindex{ lc($model{'nodes'}{$i}{'bones'}[$j][$k]) }] == -1) {
              $model{'nodes'}{$i}{'index2node'}[$work] = $nodeindex{ lc($model{'nodes'}{$i}{'bones'}[$j][$k]) };
              $model{'nodes'}{$i}{'node2index'}[$nodeindex{ lc($model{'nodes'}{$i}{'bones'}[$j][$k]) }] = $work++;
            }
            $model{'nodes'}{$i}{'Bbones'}[$j][$k] = $model{'nodes'}{$i}{'weights'}[$j][$k];
            $model{'nodes'}{$i}{'Bbones'}[$j][$k+4] = $model{'nodes'}{$i}{'node2index'}[$nodeindex{ lc($model{'nodes'}{$i}{'bones'}[$j][$k]) }];

          } else {
            $model{'nodes'}{$i}{'Bbones'}[$j][$k] = 0;
            $model{'nodes'}{$i}{'Bbones'}[$j][$k+4] = -1;
          }   
        }
      }
    }
  }
  print("\nDone reading ascii model: $file\n");
  close $ASCIIMDL;
  return \%model;
}

##################################################
# Write out a binary model
# 
sub writebinarymdl {
  my ($model, $version, $options) = (@_);
  my ($buffer, $mdxsize, $totalbytes, $nodenum, $work, $nodestart, $animstart);
  my ($file, $filepath, $timestart, $valuestart, $count);
  my ($temp1, $temp2, $temp3, $temp4);

  if ($version ne 'k1' && $version ne 'k2') {
    return;
  }

  # set up option default values
  if (!defined($options)) {
    $options = {};
  }
  if (!defined($options->{headfix})) {
    $options->{headfix} = 0;
  }

  $file = $model->{'filename'};
  $filepath = $model->{'filepath+name'};

  $nodenum = $model->{'nodes'}{'truenodenum'};
  open(BMDLOUT, ">", "$filepath-$version-bin.mdl") or die "can't open MDL file $filepath-$version-bin.mdl\n";
  binmode(BMDLOUT);
  open(BMDXOUT, ">", "$filepath-$version-bin.mdx") or die "can't open MDX file $filepath-$version-bin.mdx\n";
  binmode(BMDXOUT);
 
  #write out MDX
  seek (BMDXOUT, 0, 0);
  for (my $i = 0; $i < $model->{'nodes'}{'truenodenum'}; $i++) {
    #print ("MDX: $i\n");
    if (($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_MESH) &&
        $model->{'nodes'}{$i}{'mdxdatasize'} > 0 &&
        $model->{'nodes'}{$i}{'mdxdatabitmap'} != 0) {
      $model->{'nodes'}{$i}{'mdxstart'} = tell(BMDXOUT);
      #print($model->{'nodes'}{$i}{'vertnum'} . "|writing MDX data for node $i at starting location $model->{'nodes'}{$i}{'mdxstart'} datasize: $model->{'nodes'}{$i}{'mdxdatasize'}\n");
      for (my $j = 0; $j < $model->{'nodes'}{$i}{'vertnum'}; $j++) {
        if ($model->{'nodes'}{$i}{'mdxdatabitmap'} & MDX_VERTICES) {
          $buffer = pack("f",$model->{'nodes'}{$i}{'verts'}[$j][0]);
          $buffer .= pack("f",$model->{'nodes'}{$i}{'verts'}[$j][1]);
          $buffer .= pack("f",$model->{'nodes'}{$i}{'verts'}[$j][2]);
        }
        if ($model->{'nodes'}{$i}{'mdxdatabitmap'} & MDX_VERTEX_NORMALS) {
          $buffer .= pack("f",$model->{'nodes'}{$i}{'vertexnormals'}{$j}[0]);
          $buffer .= pack("f",$model->{'nodes'}{$i}{'vertexnormals'}{$j}[1]);
          $buffer .= pack("f",$model->{'nodes'}{$i}{'vertexnormals'}{$j}[2]);
        }
        # if this mesh has uv coordinates add them in
        if ($model->{'nodes'}{$i}{'mdxdatabitmap'} & MDX_TEX0_VERTICES) {
          $buffer .= pack("f",$model->{'nodes'}{$i}{'tverts'}[$model->{'nodes'}{$i}{'tverti'}{$j}][0]);
          $buffer .= pack("f",$model->{'nodes'}{$i}{'tverts'}[$model->{'nodes'}{$i}{'tverti'}{$j}][1]);
        }
        if ($model->{'nodes'}{$i}{'mdxdatabitmap'} & MDX_TEX1_VERTICES) {
          $buffer .= pack("f",$model->{'nodes'}{$i}{'tverts1'}[$model->{'nodes'}{$i}{'tverti'}{$j}][0]);
          $buffer .= pack("f",$model->{'nodes'}{$i}{'tverts1'}[$model->{'nodes'}{$i}{'tverti'}{$j}][1]);
        }
        if ($model->{'nodes'}{$i}{'mdxdatabitmap'} & MDX_TEX2_VERTICES) {
          $buffer .= pack("f",$model->{'nodes'}{$i}{'tverts2'}[$model->{'nodes'}{$i}{'tverti'}{$j}][0]);
          $buffer .= pack("f",$model->{'nodes'}{$i}{'tverts2'}[$model->{'nodes'}{$i}{'tverti'}{$j}][1]);
        }
        if ($model->{'nodes'}{$i}{'mdxdatabitmap'} & MDX_TEX3_VERTICES) {
          $buffer .= pack("f",$model->{'nodes'}{$i}{'tverts3'}[$model->{'nodes'}{$i}{'tverti'}{$j}][0]);
          $buffer .= pack("f",$model->{'nodes'}{$i}{'tverts3'}[$model->{'nodes'}{$i}{'tverti'}{$j}][1]);
        }
        # if this mesh has normal mapping, include the tangent space data
        if ($model->{'nodes'}{$i}{'mdxdatabitmap'} & MDX_TANGENT_SPACE) {
          $buffer .= pack('f[9]', @{$model->{'nodes'}{$i}{'Btangentspace'}[$j]});
        }
        # if this is a skin mesh node then add in the bone weights
        if ($model->{'nodes'}{$i}{'nodetype'} == NODE_SKIN) {
          $buffer .= pack("f*", @{$model->{'nodes'}{$i}{'Bbones'}[$j]} );
        }
        $mdxsize += length($buffer);
        print (BMDXOUT $buffer);
      }
      # add on the end padding
      # 3 1x10^7 floats followed by enough 0's to make one row
      $buffer = pack(
        "f*", 10000000, 10000000, 10000000,
        (0) x ( # using repetition operator to get the correct # of 0's
          ($model->{'nodes'}{$i}{'mdxdatasize'} / 4) - # floats in a row
          3 - # subtract the 3 1x10^7s
          (($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_SKIN) ? 8 : 0) # subtract 8 skin floats
        )
      );
      # after padding to one row, we may need to pad further to maintain 16-byte alignment,
      # this is why MDX starting positions always end in 0 in vanilla models
      if (($mdxsize + length($buffer)) % 16) {
        # the interior mod operation tells us how many bytes into a 16-byte row we are in
        # subtracting from 16 gives us the number of bytes we need to add,
        # divide by 4 to get the number of 4-byte floats we need
        $buffer .= pack(
          'f*', (0) x (
            (16 - (($mdxsize + length($buffer)) % 16)) / 4
          )
        );
      }
      # this is the old mdlops way based on implicit assumption of 24-byte rows
      #$buffer = pack("f*",10000000, 10000000, 10000000, 0, 0, 0, 0, 0);
      $mdxsize += length($buffer);
      print (BMDXOUT $buffer);
      if ($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_SKIN) {
        # more mysterious padding, this one for skin nodes only
        $buffer = pack("f*",1, 0, 0, 0, 0, 0, 0, 0);
        $mdxsize += length($buffer);
        print (BMDXOUT $buffer);
      }
    }
  }
  close BMDXOUT;
  #build the part names array
  for (my $i = 0; $i < $nodenum; $i++) {
    $model->{'names'}{'raw'} .= pack("Z*", $model->{'partnames'}[$i]);
  }  

  #write out binary MDL
  #write out the file header
  seek (BMDLOUT, 0, 0);
  $buffer = pack("LLL", 0, 0, $mdxsize);
  $totalbytes += length($buffer);
  print (BMDLOUT $buffer);

  #write out the geometry header
  # seek (BMDLOUT, 12, 0);
  if($version eq 'k1') {
    $buffer =  pack("LLZ[32]", 4273776, 4216096, $model->{'name'});  # for kotor 1
  } else {
    $buffer =  pack("LLZ[32]", 4285200, 4216320, $model->{'name'});  # for kotor 2
  }
  $totalbytes += length($buffer);
  print (BMDLOUT $buffer);
  # write out placeholder for root node start location
  $model->{'rootnode'}{'start'} = tell(BMDLOUT);
  $buffer = pack("L", 0);
  $totalbytes += length($buffer);
  print (BMDLOUT $buffer);
  $buffer = pack("L", $nodenum);
  $buffer .= pack("L[7]C[4]", 0,0,0,0,0,0,0,2,49,150,189);
  $totalbytes += length($buffer);
  print (BMDLOUT $buffer);
  
  #write out the model header
  # seek (BMDLOUT, 92, 0);
  $buffer =  pack("C[4]L", $classification{$model->{'classification'}},
                           # this is always 4 for placeables ...
                           # it is sometimes 2 for characters, but no idea why yet
                           # it is 0 for all other classifications of models
                           $classification{$model->{'classification'}} == 32 ? 4 : 0,
                           0,1,0);
  $totalbytes += length($buffer);
  print (BMDLOUT $buffer);
  $model->{'animroot'}{'start'} = tell(BMDLOUT);
  $buffer =  pack("L*", 0, $model->{'numanims'}, $model->{'numanims'}, 0);
  $buffer .= pack("f*", $model->{'bmin'}[0], $model->{'bmin'}[1], $model->{'bmin'}[2]);
  $buffer .= pack("f*", $model->{'bmax'}[0], $model->{'bmax'}[1], $model->{'bmax'}[2]);
  if ( $model->{'supermodel'} eq "mdlops" ) {
    $buffer .= pack("ffZ[32]", $model->{'radius'}, $model->{'animationscale'}, "NULL");
  } else {
    $buffer .= pack("ffZ[32]", $model->{'radius'}, $model->{'animationscale'}, $model->{'supermodel'});
  }
  $totalbytes += length($buffer);
  print (BMDLOUT $buffer);

  #write out the name array header
  # seek (BMDLOUT, 180, 0);
  $model->{'nameheader'}{'start'} = tell(BMDLOUT);
  $buffer =  pack("LLLL", 0, 0, $mdxsize, 0);
  $buffer .= pack("LLL", 80+88+28, $nodenum, $nodenum);
  $totalbytes += length($buffer);
  print (BMDLOUT $buffer);
  #write out the name indexes
  $buffer = pack("L", 80+88+28+(4*$nodenum));
  $work = 0;
  for (my $i = 1; $i < $nodenum; $i++) {
    $work += length( $model->{'partnames'}[$i-1] )+1;
    #$work += length($partname[$i-1])+1;
    $buffer .= pack("L", 80+88+28+(4*$nodenum)+$work);
  }  
  $totalbytes += length($buffer);
  print (BMDLOUT $buffer);
  #write out the part names
  $totalbytes += length($model->{'names'}{'raw'});
  print (BMDLOUT $model->{'names'}{'raw'});

  $animstart = tell(BMDLOUT);

  if ($model->{'numanims'} > 0) {
    # animations
    # write out placeholders for the animation indexes
    $buffer = "l" x $model->{'numanims'};
    $buffer = pack($buffer);
    $totalbytes += length($buffer);
    print (BMDLOUT $buffer);  
  
    # write out the actual animations
    for (my $i = 0; $i < $model->{'numanims'}; $i++) {
      seek(BMDLOUT, $totalbytes, 0);
      $model->{'anims'}{$i}{'start'} = tell(BMDLOUT);
      #write out the animation geometry header
      if($version eq 'k1') {
        $buffer =  pack("LLZ[32]", 4273392, 4451552, $model->{'anims'}{$i}{'name'});  # for kotor 1
      } else {
        $buffer =  pack("LLZ[32]", 4284816, 4522928, $model->{'anims'}{$i}{'name'});  # for kotor 2
      }
      $totalbytes += length($buffer);
      print (BMDLOUT $buffer);    
      # write out placeholder for anim node start location
      $model->{'anims'}{$i}{'nodes'}{'startloc'} = tell(BMDLOUT);
      $buffer = pack("L", 0);
      $totalbytes += length($buffer);
      print (BMDLOUT $buffer);
#      $buffer = pack("L", $model->{'anims'}{$i}{'nodes'}{'numnodes'});
      $buffer = pack("L", $nodenum);
      $buffer .= pack("L[8]", 0,0,0,0,0,0,0,5);
      $totalbytes += length($buffer);
      print (BMDLOUT $buffer);

      # write out the animation header
      $buffer  = pack("f", $model->{'anims'}{$i}{'length'} );
      $buffer .= pack("f", $model->{'anims'}{$i}{'transtime'} );
      $buffer .= pack("Z[32]", $model->{'anims'}{$i}{'animroot'} );
      $totalbytes += length($buffer);
      print (BMDLOUT $buffer);
      $model->{'anims'}{$i}{'eventsloc'} = tell(BMDLOUT);
      $buffer  = pack("LLLL", 0, $model->{'anims'}{$i}{'numevents'}, $model->{'anims'}{$i}{'numevents'}, 0);
      $totalbytes += length($buffer);
      print (BMDLOUT $buffer);    

      # write out the animation events (ifany)
      if ( $model->{'anims'}{$i}{'numevents'} > 0 ) {
        $buffer = "";
        $model->{'anims'}{$i}{'eventsstart'} = tell(BMDLOUT);
        foreach ( 0..($model->{'anims'}{$i}{'numevents'} - 1) ) {
          $buffer .= pack("fZ[32]", $model->{'anims'}{$i}{'eventtimes'}[$_], $model->{'anims'}{$i}{'eventnames'}[$_]);
        }
        $totalbytes += length($buffer);
        print (BMDLOUT $buffer);
      }
      $model->{'anims'}{$i}{'nodes'}{'start'} = tell(BMDLOUT);
      # fill in some blanks
      # the start of this animations nodes
      seek(BMDLOUT, $model->{'anims'}{$i}{'nodes'}{'startloc'}, 0);
      print (BMDLOUT pack("L", ($model->{'anims'}{$i}{'nodes'}{'start'} - 12) ) );
      if ($model->{'anims'}{$i}{'numevents'} > 0) {
        # the start of this animations events
         seek(BMDLOUT, $model->{'anims'}{$i}{'eventsloc'}, 0);
        print(BMDLOUT pack("L", ($model->{'anims'}{$i}{'eventsstart'} - 12) ) );
      }
    
      # write out animation nodes recursively
      $totalbytes = writebinarynode($model, $model->{'anims'}{$i}{'nodelist'}->[0], $totalbytes, $version, $i);

    } # for (my $i = 0; $i < $model->{'numanims'}; $i++) {

    # fill in the animation indexes blanks
    $buffer = "";
    for (my $i = 0; $i < $model->{'numanims'}; $i++) {
      $buffer .= pack("L", ($model->{'anims'}{$i}{'start'} - 12) );
    }
    if ($animstart < 20) {die;}
    seek(BMDLOUT, $animstart, 0);
    print(BMDLOUT $buffer);
    # fill in the animation start location
    if ($model->{'animroot'}{'start'} < 20) {die;}
    seek(BMDLOUT, $model->{'animroot'}{'start'}, 0);
    print(BMDLOUT pack("L", ($animstart - 12) ));
    
  } # if ($model->{'numanims'} > 0) {
  
  #$nodestart = tell(BMDLOUT);
  $nodestart = $totalbytes;
  my $nh_nodestart = $nodestart;
  
  # write out the nodes
    
  # now recursive because doing side-by-side comparisons of binary mdls was a real PITA before
  $totalbytes = writebinarynode($model, 0, $totalbytes, $version, "geometry");

  # VarsityPuppet's headfixer method:
  if ($options->{headfix}) {
      # head models want the root node pointer in the names header to point at neck_g,
      # not the actual root node, so adjust the nh_nodestart value here w/
      # the location of neck_g
      for my $id (keys @{$model->{partnames}}) {
          if ($model->{partnames}[$id] eq 'neck_g') {
              $nh_nodestart = $model->{nodes}{$id}{'header'}{'start'};
              last;
          }
      }
  }

  #fill in some blanks
  #the size of the mdl (minus the file header)
  seek(BMDLOUT, 4, 0);
  print(BMDLOUT pack("L", $totalbytes - 12));
  # the start of the geomtrey nodes
  if ($model->{'rootnode'}{'start'} < 20) {die;}
  seek(BMDLOUT, $model->{'rootnode'}{'start'}, 0);
  print(BMDLOUT pack("L", ($nodestart - 12) ));
  # the start of the animations
  if ($model->{'animroot'}{'start'} < 20) {die;}
  seek(BMDLOUT, $model->{'animroot'}{'start'}, 0);
  print(BMDLOUT pack("L", $animstart - 12));  
  # fill in the node start location in the names header
  seek(BMDLOUT, $model->{'nameheader'}{'start'}, 0);
  print(BMDLOUT pack("L", ($nh_nodestart - 12) ));

  print("done with: $filepath\n");

  close BMDLOUT;
}

#####################################################################
# called only by readasciimdl
# a recursive sub to post-process mesh information in nodes
# code shamelessly cribbed from Torlack's C++ de/compiler
sub postprocessnodes {
  my ($node, $model, $anim) = (@_);
    
  if ($node->{'nodetype'} & NODE_HAS_MESH) {
    # zomg lots to do
    
    if ($node->{'nodetype'} & NODE_HAS_SKIN) {
    
      if (!$anim) {
        # QBones and TBones for model geometry only
        if (! exists($node->{'TBones'}) ) {
          # QBones: will store the orientations (direction) from every other node to this node
          # QBones: will store the positions (length) from every other node to this node
          $node->{'TBones'} = [];
          $node->{'QBones'} = [];

          # Start by getting the distance/length from this node to the root node.
          # Get current position/orientation, then reverse it.
          my (@position, @orientation, @parentposition, @parentorientation, $parent);
          getreversedpositionorientation(\@position, \@orientation, $node);

          # Combine with reversed parent orientations / positions, right up to the root
          $parent = $node;
          while ($parent->{'parentnodenum'} != -1) {
            $parent = $model->{'nodes'}{$parent->{'parentnodenum'}};
            getreversedpositionorientation(\@parentposition, \@parentorientation, $parent); # The rotation's done in here
            addvectors(\@position, \@parentposition, \@position);
            multiplyquaternions(\@orientation, \@parentorientation, \@orientation);
          }

          # okay, now we build the tbone and qbone arrays
          my $count = buildtqbonearrays($model->{'nodes'}{0}, $model, \@position, \@orientation, $node->{'TBones'}, $node->{'QBones'}, 0);

          # You think you're done.  But no, now every element needs to get reversed, and rotated.
          # I believe this changes from (distance/length from this node to other node) to
          # (distance/length from other node to this node).  But I'm too lazy to work out the math to see if that's correct.
          # Also, we will now adjust our orientation quaternions to be in the w,x,y,z format
          for (my $i = 0; $i < $count; $i++) {
            $node->{'QBones'}[$i][3] = - $node->{'QBones'}[$i][3];
            
            $node->{'TBones'}[$i][0] = - $node->{'TBones'}[$i][0];
            $node->{'TBones'}[$i][1] = - $node->{'TBones'}[$i][1];
            $node->{'TBones'}[$i][2] = - $node->{'TBones'}[$i][2];

            rotatevector($node->{'TBones'}[$i], @{$node->{'QBones'}[$i]});
            my $temp = $node->{'QBones'}[$i][3];
            $node->{'QBones'}[$i][3] = $node->{'QBones'}[$i][2];
            $node->{'QBones'}[$i][2] = $node->{'QBones'}[$i][1];
            $node->{'QBones'}[$i][1] = $node->{'QBones'}[$i][0];
            $node->{'QBones'}[$i][0] = $temp;
          }

          # apparently now our T and Q bones are good to go.  yay.
        }
      }
    }
  }
  # DISABLED (i thought this might be needed for sabers, but it wasn't, it will work if used)
  # for orientation keyed controllers in animation,
  # compress and encode quaternions as 3 10-bit floats
  # into a single 32-bit float
  if (0 && $anim && defined($node->{'Bcontrollers'}{20}) &&
      scalar(@{$node->{'Bcontrollers'}{20}{'values'}[0]}) == 4) {
      # encode compressed quaternions
      # decompress algorithm:
      #   leave first value alone completely
      #   generate 4 values from 2nd value
      #   1 = q.x = 1 - ((v1 & 7ff) / 1023)
      #   2 = q.y = 1 - ((v1 >> 11 & 7ff) / 1023)
      #   3 = q.z = 1 - ((v1 >> 22) / 511)
      #   0.5, 0.6, 0.7
      #   0x3f000000, 0x3f19999a, 0x3f333333
      #   1 - 0.7 = (v1 >> 22) / 511
      #   (1 - 0.7) * 511 = v1 >> 22
      # so, to generate, take v3 * 511
      #   y = 1 - x
      #   (1 - v3) * 511 << 11
      #   (1 - v2) * 1023 << 11
      #   (1 - v1) * 1023
      #
      # this loop is going to take each unit quaternion and compress it into
      # a single floating point number. so that is 4 floats down to 1.
      # how does it work? i have *sort of* a clue about that?
      # this guy def does: http://physicsforgames.blogspot.com/2010/03/quaternion-tricks.html
      # basically one of the nums, w, is deriveable from the other 3, so it goes away
      # the trick for x,y,z relies on the fact that they are all in the range of -1,1
      foreach (@{$node->{'Bcontrollers'}{20}{'values'}}) {
          # it seems like we already have unit quaternions,
          # so no normalization necessary
          #my $f = ($_->[0] ** 2) + ($_->[1] ** 2) + ($_->[2] ** 2);
          #print Dumper($_);
          #print "FACTOR: $f\n";
          #if ($f > 0) {
          #    $_ = [ map {
          #      $_ * $f;
          #    } @{$_} ];
          #}

          my ($qx, $qy, $qz) = @{$_}[0..2];
          #print Dumper($_);
          $_->[0] = ((1.0 - $qz) * 511);
          #print Dumper($_);
          $_->[0] = $_->[0] << 11;
          #print Dumper($_);
          $_->[0] |= ((1.0 - $qy) * 1023) & 0x7ff;
          $_->[0] = $_->[0] << 11;
          #print Dumper($_);
          $_->[0] |= ((1.0 - $qx) * 1023) & 0x7ff;
          #print Dumper($_);

          # remove elements 2,3,4 and reduce the total quantity of controller data on the node
          delete $_->[1];
          delete $_->[2];
          delete $_->[3];
          $node->{'controllerdatanum'} -= 3;

          #print Dumper($_);
          #my $temp = $_->[0];
          #print Dumper((
          #  (1.0 - (($temp & 0x7ff) / 1023.0)),
          #  (1.0 - ((($temp >> 11) & 0x7ff) / 1023.0)),
          #  (1.0 - ((($temp >> 22) & 0x7ff) / 511.0))
          #));
      }
  }

  # recursify!
  foreach my $child ( 1..$node->{'childcount'} ) {
    postprocessnodes($model->{'nodes'}{$node->{'children'}[($child - 1)]}, $model, $anim);
  }
}

###########################################################
# Used by postprocessnodes.  Recursive.
# Initialize tbone and qbone arrays.
# 
sub buildtqbonearrays {
  my ($node, $model, $position, $orientation, $tbones, $qbones, $i) = (@_);
  
  my (@currentposition, @currentorientation);
  # get position and orientation
  getpositionorientation(\@currentposition, \@currentorientation, $node);
    
  # rotate position and add it, then store
  rotatevector(\@currentposition, @{$orientation});
  addvectors($position, \@currentposition, $position);
  $tbones->[$i][0] = $position->[0];
  $tbones->[$i][1] = $position->[1];
  $tbones->[$i][2] = $position->[2];
  
  # combine orientations and store
  multiplyquaternions($orientation, \@currentorientation, $orientation);
  $qbones->[$i][0] = $orientation->[0];
  $qbones->[$i][1] = $orientation->[1];
  $qbones->[$i][2] = $orientation->[2];
  $qbones->[$i][3] = $orientation->[3];
  
  $i++;
  
  # recurse on children
  my (@newposition, @neworientation);
  foreach my $child ( 1..$node->{'childcount'} ) {
    @newposition = @$position;
    @neworientation = @$orientation;
    $i = buildtqbonearrays($model->{'nodes'}{$node->{'children'}[($child - 1)]}, $model, \@newposition, \@neworientation, $tbones, $qbones, $i);
  }
  
  return $i;
}

###########################################################
# Get the position and orientation of the given node
# 
sub getpositionorientation {
  my ($position, $orientation, $node) = (@_);

  if (exists($node->{'Acontrollers'}{8})) { #pos
    $position->[0] = $node->{'Bcontrollers'}{8}{'values'}[0][0];
    $position->[1] = $node->{'Bcontrollers'}{8}{'values'}[0][1];
    $position->[2] = $node->{'Bcontrollers'}{8}{'values'}[0][2];
  } else {
    @{$position} = (0.0, 0.0, 0.0);
  }
  if (exists($node->{'Acontrollers'}{20})) { #orient. x, y, z, w
    $orientation->[0] = $node->{'Bcontrollers'}{20}{'values'}[0][0];
    $orientation->[1] = $node->{'Bcontrollers'}{20}{'values'}[0][1];
    $orientation->[2] = $node->{'Bcontrollers'}{20}{'values'}[0][2];
    $orientation->[3] = $node->{'Bcontrollers'}{20}{'values'}[0][3]; 
  } else {
    @{$orientation} = (0.0, 0.0, 0.0, 1.0);
  }
}

###########################################################
# Get the flipped position and orientation of the given node.
# 
sub getreversedpositionorientation {
# get and flip position and orientation
  my ($position, $orientation, $node) = (@_);
  getpositionorientation($position, $orientation, $node);
  @{$position} = ( - $position->[0],
                   - $position->[1],
                   - $position->[2]);
  $orientation->[3] = - $orientation->[3];
  rotatevector($position, @{$orientation});
}

###########################################################
# Rotate vector v about quaternion q
# All quaternions here are x,y,z,w.
# 
sub rotatevector {

  my ($v, @q) = (@_);
             # v: 0 x, 1 y, 2 z
  my @qtemp; # 0 x, 1 y, 2 z, 3 w
  
  if ($v->[0] == 0 && $v->[1] == 0 && $v->[2] == 0) {
    #null vector
    return;
  }

# Here's how it looks by using straight multiplications
#  my (@vm, @qm, @qv, @qbar, @qout);
#  @vm = ($v->[0], $v->[1], $v->[2], 0);
#  @qv = [];
#  
#  multiplyquaternions(\@q, \@vm, \@qv);
# 
#  @qbar = (-$q[0], -$q[1], -$q[2], $q[3]);
#  
#  multiplyquaternions(\@qv, \@qbar, \@qout);
#
#  $v->[0] = $qout[0];
#  $v->[1] = $qout[1];
#  $v->[2] = $qout[2];

# But I went and worked it out.  Matrix algebra, what fun.
  my ($x, $y, $z);
  
  $x =  $v->[0] * ($q[3] * $q[3] + $q[0] * $q[0] - $q[1] * $q[1] - $q[2] * $q[2]) +
        $v->[1] * 2 * ($q[0] * $q[1] - $q[3] * $q[2]) +
        $v->[2] * 2 * ($q[1] * $q[3] + $q[0] * $q[2]);
        
  $y =  $v->[0] * 2 * ($q[0] * $q[1] + $q[3] * $q[2]) +
        $v->[1] * ($q[3] * $q[3] - $q[0] * $q[0] + $q[1] * $q[1] - $q[2] * $q[2]) +
        $v->[2] * 2 * ( - $q[3] * $q[0] + $q[1] * $q[2]);
  
  $z =  $v->[0] * 2 * ( - $q[3] * $q[1] + $q[0] * $q[2]) +
        $v->[1] * 2 * ($q[3] * $q[0] + $q[1] * $q[2]) +
        $v->[2] * ($q[3] * $q[3] - $q[0] * $q[0] - $q[1] * $q[1] + $q[2] * $q[2]);
  
  $v->[0] = $x;
  $v->[1] = $y;
  $v->[2] = $z;

}

###########################################################
# Add vectors v1 and v2 and put result in v3.
# 3-vectors only.  Pass in as refs.
# 
sub addvectors {
  my ($v1, $v2, $v3) = (@_);
  $v3->[0] = $v1->[0] + $v2->[0];
  $v3->[1] = $v1->[1] + $v2->[1];
  $v3->[2] = $v1->[2] + $v2->[2];
}

###########################################################
# Multiply q1 and q2 and put the result in q3.
# All quaternions of the form (x, y, z, w). Pass as refs.
sub multiplyquaternions {
  my ($q1, $q2, $q3) = (@_);
  my @qtemp;

  $qtemp[0] =   $q1->[3] * $q2->[0] - $q1->[2] * $q2->[1] + $q1->[1] * $q2->[2] + $q1->[0] * $q2->[3];
  $qtemp[1] =   $q1->[2] * $q2->[0] + $q1->[3] * $q2->[1] - $q1->[0] * $q2->[2] + $q1->[1] * $q2->[3];
  $qtemp[2] = - $q1->[1] * $q2->[0] + $q1->[0] * $q2->[1] + $q1->[3] * $q2->[2] + $q1->[2] * $q2->[3];
  $qtemp[3] = - $q1->[0] * $q2->[0] - $q1->[1] * $q2->[1] - $q1->[2] * $q2->[2] + $q1->[3] * $q2->[3];
  
  @{$q3} = @qtemp;
}

###########################################################
# Multiply q1 and q2 and return the result.
# All quaternions of the form (x, y, z, w). Pass as refs.
sub quaternion_multiply {
  my ($quat1, $quat2) = @_;
  my @q1 = @{$quat1};
  my @q2 = @{$quat2};
  # if either is only 3 coordinates, assume this is a point that we are rotating,
  # which is done by making it into a w = 0 quaternion
  if (scalar(@q1) == 3) {
    $q1[3] = 0.0;
  }
  if (scalar(@q2) == 3) {
    $q2[3] = 0.0;
  }
  return [
      $q1[3] * $q2[0] - $q1[2] * $q2[1] + $q1[1] * $q2[2] + $q1[0] * $q2[3],
      $q1[2] * $q2[0] + $q1[3] * $q2[1] - $q1[0] * $q2[2] + $q1[1] * $q2[3],
    - $q1[1] * $q2[0] + $q1[0] * $q2[1] + $q1[3] * $q2[2] + $q1[2] * $q2[3],
    - $q1[0] * $q2[0] - $q1[1] * $q2[1] - $q1[2] * $q2[2] + $q1[3] * $q2[3]
  ];
}

###########################################################
# Apply quaternion rotation to vector/point position
# This is an application of the 'sandwich product' method of rotating
# vectors using quaternions: v' = q * v * q^-1
# The vector is made into a quaternion by adding a 0 scalar (w) value
sub quaternion_apply {
  my ($quat, $vertex) = @_;
  return quaternion_multiply(
    quaternion_multiply($quat, [ @{$vertex}, 0.0 ]),
    [ -1.0 * $quat->[0],
      -1.0 * $quat->[1],
      -1.0 * $quat->[2],
      $quat->[3] ]
  );
}

#####################################################################
sub writebinarynode
{
    my ($ref, $i, $totalbytes, $version, $type) = (@_);
    my ($buffer, $count, $work, $timestart, $valuestart, $model);
    my ($temp1, $temp2, $temp3, $temp4, $ga, $controller);
    my $nodenum = $ref->{'nodes'}{'truenodenum'};
    my $nodestart = $totalbytes;

    if ($type eq "geometry")
    {
        $model = $ref;
        $ga = "geo";
    }
    else
    {
        #$model{'anims'}{$animnum}{'nodes'}{$nodenum}
        $model = $ref->{'anims'}{$type};
        $ga = "ani";
    }
  
    #print "writing node $i type $type \n";
    seek (BMDLOUT, $nodestart, 0);

    #write out the node header
    $model->{'nodes'}{$i}{'header'}{'start'} = tell(BMDLOUT);
    if ( defined( $ref->{'nodes'}{$i}{'supernode'} ) )
    {
        $work = $ref->{'nodes'}{$i}{'supernode'};
    }
    else
    {
        $work = $i;
    }
    $buffer = pack("SSSS", $model->{'nodes'}{$i}{'nodetype'}, $work, $i, 0);

    if ( $ga eq "ani" )
    {
        $buffer .= pack("L", ($model->{'start'} - 12) );
    }
    else
    {
        $buffer .= pack("L", 0);
    }
    
    if ($model->{'nodes'}{$i}{'parentnodenum'} != -1)
    {
        $buffer.= pack("L", $model->{'nodes'}{ $model->{'nodes'}{$i}{'parentnodenum'} }{'header'}{'start'} - 12);
    }
    else
    {
        $buffer.= pack("L", 0);
    }

    if ( defined( $ref->{'nodes'}{$i}{'Bcontrollers'}{8} ) && $ga eq "geo")
    {
        $buffer .= pack("f[3]", @{$ref->{'nodes'}{$i}{'Bcontrollers'}{8}{'values'}[0]});
    }
    else
    {
        $buffer .= pack("f[3]",  0, 0, 0);
    }

    if ( defined($ref->{'nodes'}{$i}{'Bcontrollers'}{20}) && $ga eq "geo")
    {
        $temp1 = $ref->{'nodes'}{$i}{'Bcontrollers'}{20}{'values'}[0][3]; # w
        $temp2 = $ref->{'nodes'}{$i}{'Bcontrollers'}{20}{'values'}[0][0]; # x
        $temp3 = $ref->{'nodes'}{$i}{'Bcontrollers'}{20}{'values'}[0][1]; # y
        $temp4 = $ref->{'nodes'}{$i}{'Bcontrollers'}{20}{'values'}[0][2]; # z
        $buffer .= pack("f[4]", $temp1, $temp2, $temp3, $temp4);
    }
    else
    {
        $buffer .= pack("f[4]", 1, 0, 0, 0);
    }
    $totalbytes += length($buffer);
    print(BMDLOUT $buffer);

    #prepare the child array pointer
    $model->{'nodes'}{$i}{'childarraypointer'} = tell(BMDLOUT);
    $buffer = pack("LLL", 0, $model->{'nodes'}{$i}{'childcount'}, $model->{'nodes'}{$i}{'childcount'});
    $totalbytes += length($buffer);
    print(BMDLOUT $buffer);

    #prepare the controller array pointer and controller data array pointer
    if ($model->{'nodes'}{$i}{'controllernum'} != 0 || $model->{'nodes'}{$i}{'controllerdatanum'} != 0)
    {
        # we have controllers, so write the place holder data
        $model->{'nodes'}{$i}{'controllerpointer'} = tell(BMDLOUT);
        $buffer = pack("LLL", 0, $model->{'nodes'}{$i}{'controllernum'}, $model->{'nodes'}{$i}{'controllernum'});
        $totalbytes += length($buffer);
        print(BMDLOUT $buffer);

        $model->{'nodes'}{$i}{'controllerdatapointer'} = tell(BMDLOUT);
        $buffer = pack("LLL", 0, $model->{'nodes'}{$i}{'controllerdatanum'}, $model->{'nodes'}{$i}{'controllerdatanum'});
        $totalbytes += length($buffer);
        print(BMDLOUT $buffer);
    }
    else
    {
        # we have no controllers, so fill with zeroes
        $buffer = pack("LLL", 0, 0, 0);
        $buffer .= pack("LLL", 0, 0, 0);
        $totalbytes += length($buffer);
        print (BMDLOUT $buffer);
    }  

    #write out the light sub header and data (if any)
    if ($model->{'nodes'}{$i}{'nodetype'} == 3)
    {
        #$buffer  = pack("fLLLLLLLLLLLLLLL", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        # make our lives a little easier by assuring that these lists at least exist
        foreach ('flaresizes', 'flarepositions', 'flarecolorshifts', 'texturenames') {
          if (!defined($model->{'nodes'}{$i}{$_})) {
            $model->{'nodes'}{$i}{$_} = [];
          }
        }
        $buffer  = pack("fLLL", $model->{'nodes'}{$i}{'flareradius'}, 0, 0, 0);
        $totalbytes += length($buffer);
        print (BMDLOUT $buffer);
        $model->{'nodes'}{$i}{'flaresizespointer'} = tell(BMDLOUT);
        $buffer  = pack('LLL', 0, scalar(@{$model->{'nodes'}{$i}{'flaresizes'}}), scalar(@{$model->{'nodes'}{$i}{'flaresizes'}}));
        $totalbytes += length($buffer);
        print (BMDLOUT $buffer);
        $model->{'nodes'}{$i}{'flarepositionspointer'} = tell(BMDLOUT);
        $buffer  = pack('LLL', 0, scalar(@{$model->{'nodes'}{$i}{'flarepositions'}}), scalar(@{$model->{'nodes'}{$i}{'flarepositions'}}));
        $totalbytes += length($buffer);
        print (BMDLOUT $buffer);
        $model->{'nodes'}{$i}{'flarecolorshiftspointer'} = tell(BMDLOUT);
        $buffer  = pack('LLL', 0, scalar(@{$model->{'nodes'}{$i}{'flarecolorshifts'}}), scalar(@{$model->{'nodes'}{$i}{'flarecolorshifts'}}));
        $totalbytes += length($buffer);
        print (BMDLOUT $buffer);
        $model->{'nodes'}{$i}{'texturenamespointer'} = tell(BMDLOUT);
        $buffer  = pack('LLL', 0, scalar(@{$model->{'nodes'}{$i}{'texturenames'}}), scalar(@{$model->{'nodes'}{$i}{'texturenames'}}));
        $totalbytes += length($buffer);
        print (BMDLOUT $buffer);

        $buffer  = pack("L", $model->{'nodes'}{$i}{'lightpriority'});
        $buffer .= pack("L", $model->{'nodes'}{$i}{'ambientonly'});
        $buffer .= pack("L", $model->{'nodes'}{$i}{'ndynamictype'});
        $buffer .= pack("L", $model->{'nodes'}{$i}{'affectdynamic'});
        $buffer .= pack("L", $model->{'nodes'}{$i}{'shadow'});
        $buffer .= pack("L", $model->{'nodes'}{$i}{'flare'});
        $buffer .= pack("L", $model->{'nodes'}{$i}{'fadinglight'});
        $totalbytes += length($buffer);
        print (BMDLOUT $buffer);

        # write out flare data: texture names, sizes, positions, colorshifts
        if (scalar(@{$model->{'nodes'}{$i}{'flarepositions'}})) {
            # write out placeholders for the pointers to the texture names
            $model->{'nodes'}{$i}{'texturenamespointerlocation'} = tell(BMDLOUT);
            $model->{'nodes'}{$i}{'texturenameslocation'} = tell(BMDLOUT);
            my $name_pointers = [];
            foreach (1..scalar(@{$model->{'nodes'}{$i}{'texturenames'}})) {
                $name_pointers = [ @{$name_pointers}, 0 ];
            }
            $buffer  = pack('L' x scalar(@{$model->{'nodes'}{$i}{'texturenames'}}), @{$name_pointers});
            $totalbytes += (scalar(@{$model->{'nodes'}{$i}{'texturenames'}}) * 4);
            print (BMDLOUT $buffer);

            # write out the texture name strings
            $model->{'nodes'}{$i}{'texturenameslocations'} = [];
            for my $texname (@{$model->{'nodes'}{$i}{'texturenames'}}) {
                $model->{'nodes'}{$i}{'texturenameslocations'} = [
                    @{$model->{'nodes'}{$i}{'texturenameslocations'}},
                    # subtract 12 (file header length) from offsets now
                    tell(BMDLOUT) - 12
                ];
                $buffer = pack('Z*', $texname);
                #print "TEX: $buffer\n";
                $totalbytes += length($buffer);
                print (BMDLOUT $buffer);
            }

            # go back and write out the name pointers
            seek(BMDLOUT, $model->{'nodes'}{$i}{'texturenamespointerlocation'}, 0);
            print (BMDLOUT pack('L' x scalar(@{$model->{'nodes'}{$i}{'texturenameslocations'}}),
                                 @{$model->{'nodes'}{$i}{'texturenameslocations'}}));

            # return file position to head
            seek(BMDLOUT, $totalbytes, 0);

            # note offset and write flaresizes
            $model->{'nodes'}{$i}{'flaresizeslocation'} = tell(BMDLOUT);
            $buffer = pack('f' x scalar(@{$model->{'nodes'}{$i}{'flaresizes'}}), @{$model->{'nodes'}{$i}{'flaresizes'}});
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            # note offset and write flarepositions
            $model->{'nodes'}{$i}{'flarepositionslocation'} = tell(BMDLOUT);
            $buffer = pack('f' x scalar(@{$model->{'nodes'}{$i}{'flarepositions'}}), @{$model->{'nodes'}{$i}{'flarepositions'}});
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            # note offset and write flarecolorshifts
            $buffer = '';
            $model->{'nodes'}{$i}{'flarecolorshiftslocation'} = tell(BMDLOUT);
            for my $col_shift (@{$model->{'nodes'}{$i}{'flarecolorshifts'}}) {
                $buffer .= pack('fff', @{$col_shift});
            }
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            # go back and write out the other pointers
            seek(BMDLOUT, $model->{'nodes'}{$i}{'flaresizespointer'}, 0);
            print(BMDLOUT pack('L', $model->{'nodes'}{$i}{'flaresizeslocation'} - 12));
            seek(BMDLOUT, $model->{'nodes'}{$i}{'flarepositionspointer'}, 0);
            print(BMDLOUT pack('L', $model->{'nodes'}{$i}{'flarepositionslocation'} - 12));
            seek(BMDLOUT, $model->{'nodes'}{$i}{'flarecolorshiftspointer'}, 0);
            print(BMDLOUT pack('L', $model->{'nodes'}{$i}{'flarecolorshiftslocation'} - 12));
            seek(BMDLOUT, $model->{'nodes'}{$i}{'texturenamespointer'}, 0);
            print(BMDLOUT pack('L', $model->{'nodes'}{$i}{'texturenameslocation'} - 12));

            # return file position to head
            seek(BMDLOUT, $totalbytes, 0);
        }
    }

    #write out the emitter sub header and data (if any)
    if ($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_EMITTER)
    {
        # size 224: 32 + 32 + 32 + 32 + 32 + 16 + 8 + 2 + 1 + 32 + 1 + 4
        $buffer = pack(
            #'l[2]f[3]l[3]Z[32]Z[32]Z[32]Z[64]Z[16]l[2]S[2]l', 0, 0,
            'f[3]L[5]Z[32]Z[32]Z[32]Z[32]Z[16]L[2]SCZ[32]CL',
            $model->{'nodes'}{$i}{'deadspace'},           # 0
            $model->{'nodes'}{$i}{'blastRadius'},         # 1
            $model->{'nodes'}{$i}{'blastLength'},         # 2
            $model->{'nodes'}{$i}{'numBranches'},         # 3
            $model->{'nodes'}{$i}{'controlptsmoothing'},  # 4
            $model->{'nodes'}{$i}{'xgrid'},               # 5
            $model->{'nodes'}{$i}{'ygrid'},               # 6
            $model->{'nodes'}{$i}{'spawntype'},           # 7
            $model->{'nodes'}{$i}{'update'},              # 8
            $model->{'nodes'}{$i}{'render'},              # 9
            $model->{'nodes'}{$i}{'blend'},               # 10
            $model->{'nodes'}{$i}{'texture'},             # 11
            $model->{'nodes'}{$i}{'chunkname'},           # 12
            $model->{'nodes'}{$i}{'twosidedtex'},         # 13
            $model->{'nodes'}{$i}{'loop'},                # 14
            $model->{'nodes'}{$i}{'emitterflags'},        # 15
            $model->{'nodes'}{$i}{'m_bFrameBlending'},    # 16
            $model->{'nodes'}{$i}{'m_sDepthTextureName'}, # 17
            $model->{'nodes'}{$i}{'m_bUnknown1'},         # 18
            $model->{'nodes'}{$i}{'m_lUnknown2'},         # 19
        );
        print (BMDLOUT $buffer);
        $totalbytes += length($buffer);
    }

    #write out the mesh sub header and data (if any)
    if ($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_MESH)
    {
        #print "mesh node type " . $model->{'nodes'}{$i}{'nodetype'} . "\n";
        # write out function pointers
        if ($version eq 'k1')
        {
            if ($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_DANGLY)  #289
            {
                $buffer =  pack("LL", 4216640, 4216624); # for kotor 1
            }
            elsif ($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_SKIN)  #97
            {
                $buffer =  pack("LL", 4216592, 4216608); # for kotor 1
            }
            else
            {
                $buffer =  pack("LL", 4216656, 4216672); # for kotor 1
            }
        }
        else
        {
            if ($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_DANGLY)  #289
            {
                $buffer =  pack("LL", 4216864, 4216848); # for kotor 2
            }
            elsif ($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_SKIN)  #97
            {
                $buffer =  pack("LL", 4216816, 4216832); # for kotor 2
            }
            else
            {
                $buffer =  pack("LL", 4216880, 4216896); # for kotor 2
            } 
        }
        $totalbytes += length($buffer);
        print(BMDLOUT $buffer);
        $model->{'nodes'}{$i}{'faceslocpointer'} = tell(BMDLOUT);
        $buffer =  pack("LLL", 0, $model->{'nodes'}{$i}{'facesnum'}, $model->{'nodes'}{$i}{'facesnum'});

        # set bounding box min, max, radius, average
        $buffer .= pack("f[3]", @{$model->{'nodes'}{$i}{'bboxmin'}});
        $buffer .= pack("f[3]", @{$model->{'nodes'}{$i}{'bboxmax'}});
        $buffer .= pack("f", $model->{'nodes'}{$i}{'radius'});
        $buffer .= pack("f[3]", @{$model->{'nodes'}{$i}{'average'}});
        $buffer .= pack("f[3]", @{$model->{'nodes'}{$i}{'diffuse'}} );
        $buffer .= pack("f[3]", @{$model->{'nodes'}{$i}{'ambient'}} );
        $buffer .= pack("L", $model->{'nodes'}{$i}{'transparencyhint'} );
        $buffer .= pack("Z[32]", $model->{'nodes'}{$i}{'bitmap'} );
        $buffer .= pack("Z[32]", $model->{'nodes'}{$i}{'bitmap2'} );
        $buffer .= pack("Z[12]", $model->{'nodes'}{$i}{'texture0'} );
        $buffer .= pack("Z[12]", $model->{'nodes'}{$i}{'texture1'} );
        #$buffer .= pack("f[14]", 0,0,0,0,0,0,0,0,0,0,0,0,0,0);
        #$buffer .= pack("f[6]", 0,0,0,0,0,0); #compile time vertex indices, left over faces
        $totalbytes += length($buffer);
        print(BMDLOUT $buffer);

        $model->{'nodes'}{$i}{'vertnumpointer'} = tell(BMDLOUT);      
        $buffer = pack("L*", 0, 1, 1);
        $totalbytes += length($buffer);
        print(BMDLOUT $buffer);

        $model->{'nodes'}{$i}{'vertlocpointer'} = tell(BMDLOUT);      
        $buffer = pack("L*", 0, 1, 1);
        $totalbytes += length($buffer);
        print(BMDLOUT $buffer);

        $model->{'nodes'}{$i}{'unknownpointer'} = tell(BMDLOUT);      
        $buffer = pack("L*", 0, 1, 1);
        $buffer .= pack("l*", -1, -1, 0);
        # the following 8 bytes are not well understood yet and probably wrong
        if ($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_SABER) {
          #$buffer .= pack("C*", 0, 0, 0, 0, 0, 0, 0, 17);
          $buffer .= pack("C*", 171, 91, 237, 62, 120, 144, 188, 1);
          #shortsbr1,6 1st lightsaber mesh plane:
          #$buffer .= pack("C*", 171, 91, 237, 62, 120, 144, 188, 1);
          #$buffer .= pack("C*", -85, 91, -19, 62, 120, -112, -68, 1);
          #shortsbr1,6 2nd lightsaber mesh plane:
          #$buffer .= pack("C*", 0, 0, 0, 0, 0, 145, 6, 2);
          #$buffer .= pack("C*", 0, 0, 0, 0, 0, -111, 6, 2);
          #lghtsbr1,2,3 1st lightsaber mesh plane:
          #$buffer .= pack("C*", 171, 91, 237, 62, 104, 176, 207, 1);
          #$buffer .= pack("C*", -85, 91, -19, 62, 104, -80, -49, 1);
          #lghtsbr1,2,3 2nd lightsaber mesh plane:
          #$buffer .= pack("C*", 0, 0, 0, 0, 232, 210, 6, 2);
          #$buffer .= pack("C*", 0, 0, 0, 0, -24, -46, 6, 2);
          #dblsbr1 1st lightsaber mesh plane:
          #$buffer .= pack("C*", 171, 91, 237, 64, 206, 192, 207, 1);
          #$buffer .= pack("C*", -85, 91, -19, 64, -50, -64, -49, 1);
          #dblsbr1 2nd lightsaber mesh plane:
          #$buffer .= pack("C*", 0, 0, 0, 0, 112, 35, 193, 1);
          #$buffer .= pack("C*", 0, 0, 0, 0, 112, 35, -63, 1);
          #dblsbr1 3rd lightsaber mesh plane:
          #$buffer .= pack("C*", 29, 133, 171, 56, 232, 45, 54, 0);
          #$buffer .= pack("C*", 29, -123, -85, 56, -24, 45, 54, 0);
          #dblsbr1 4th lightsaber mesh plane:
          #$buffer .= pack("C*", 184, 166, 239, 1, 120, 6, 232, 1);
          #$buffer .= pack("C*", -72, -90, -17, 1, 120, 6, -24, 1);
        } else {
          $buffer .= pack("C*", 3, 0, 0, 0, 0, 0, 0, 0);
        }
        $buffer .= pack('Lffff', $model->{'nodes'}{$i}{'animateuv'}, # sparkle? .lmt? might actually be animateuv
                                 $model->{'nodes'}{$i}{'uvdirectionx'},
                                 $model->{'nodes'}{$i}{'uvdirectiony'},
                                 $model->{'nodes'}{$i}{'uvjitter'},
                                 $model->{'nodes'}{$i}{'uvjitterspeed'});

        $buffer .= pack("l", $model->{'nodes'}{$i}{'mdxdatasize'});

        # don't know what this is, but is definately has something to do with textures
        # MDXDataBitmap, bitfield describing what mesh info is found in the MDX row
        # 35 = 1, 2, 32 = (i believe) verts, uv verts, normals
        #if ($model->{'nodes'}{$i}{'texturenum'} == 1)
        #{
        #    $buffer .= pack("l", 35 );
        #}
        #else
        #{
        #    $buffer .= pack("l", 33 );
        #}
        #$buffer .= pack("l*", 0, 12, -1);

        #if ($model->{'nodes'}{$i}{'mdxdatasize'} > 24)
        #{
        #    $buffer .= pack("l*", 24);
        #}
        #else
        #{
        #    $buffer .= pack("l*", -1);
        #}
        #$buffer .= pack("l*", -1, -1, -1, -1, -1, -1, -1);
        $buffer .= pack('L', $model->{'nodes'}{$i}{'mdxdatabitmap'});
        $buffer .= pack('l[11]', @{$model->{'nodes'}{$i}{'mdxrowoffsets'}});

        $buffer .= pack("ss", $model->{'nodes'}{$i}{'vertnum'}, $model->{'nodes'}{$i}{'texturenum'} );

        $buffer .= pack('C*', $model->{'nodes'}{$i}{'lightmapped'},
                              $model->{'nodes'}{$i}{'rotatetexture'},
                              $model->{'nodes'}{$i}{'m_bIsBackgroundGeometry'},
                              $model->{'nodes'}{$i}{'shadow'},
                              $model->{'nodes'}{$i}{'beaming'},
                              $model->{'nodes'}{$i}{'render'});

        if ($version eq 'k2')
        {
            $buffer .= pack("CCssL", $model->{'nodes'}{$i}{'dirt_enabled'} ? 1 : 0, 0,
                                     $model->{'nodes'}{$i}{'dirt_texture'} ? $model->{'nodes'}{$i}{'dirt_texture'} : 1,
                                     $model->{'nodes'}{$i}{'dirt_worldspace'} ? $model->{'nodes'}{$i}{'dirt_worldspace'} : 1,
                                     $model->{'nodes'}{$i}{'hologram_donotdraw'} ? 1 : 0);
        } else {
            $buffer .= pack('s', 0);
        }

        # not sure this surface area hypothesis is actually correct,
        # i have not seen it with a value that makes sense in any models...
        $buffer .= pack('fL', $model->{'nodes'}{$i}{'surfacearea'}, 0);

        if ($version eq 'k2')
        {
            # this is not placed correctly at all
            #$buffer .= pack("l*", 0, 0);
        }

        $buffer .= pack("l", $model->{'nodes'}{$i}{'mdxstart'});
        $totalbytes += length($buffer);
        print(BMDLOUT $buffer);
        $model->{'nodes'}{$i}{'vertfloatpointer'} = tell(BMDLOUT);
        $buffer = pack("l", 0);
        $totalbytes += length($buffer);
        print(BMDLOUT $buffer);

        # end of mesh subheader

        # write out the mesh sub-sub-header and data (if there is any)
        if ($model->{'nodes'}{$i}{'nodetype'} == NODE_SKIN)  # skin mesh sub-sub-header
        {
            # compile-time only array, then ptr to skin weights in mdx, then ptr to skin bone refs in mdx
            $buffer = pack("l*", 0, 0, 0, $model->{'nodes'}{$i}{'mdxboneweightsloc'},
                                          $model->{'nodes'}{$i}{'mdxboneindicesloc'});
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            # write out the bone map location place holder
            $model->{'nodes'}{$i}{'bonemaplocpointer'} = tell(BMDLOUT);
            $buffer = pack("l*", 0, $nodenum);
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            # write out qbones location place holder  (Torlack -> "QBone Ref Inv")
            $model->{'nodes'}{$i}{'qboneslocpointer'} = tell(BMDLOUT);
            $buffer = pack("l*", 0, $nodenum, $nodenum);
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            # write out unknown array2 location place holder  (Torlack -> "TBone Ref Inv")
            $model->{'nodes'}{$i}{'tboneslocpointer'} = tell(BMDLOUT);
            $buffer = pack("l*", 0, $nodenum, $nodenum);
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            # write out unknown array3 location place holder  (Torlack -> "Bone constant indices")
            $model->{'nodes'}{$i}{'skinarray3locpointer'} = tell(BMDLOUT);
            $buffer = pack("l*", 0, $nodenum, $nodenum);
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            # write out bone index (Torlack -> "Bone part numbers")
            $buffer = "";
            foreach (0 .. 17)
            {
                if(defined($model->{'nodes'}{$i}{'index2node'}[$_]))
                {
                    $buffer .= pack("s", $model->{'nodes'}{$i}{'index2node'}[$_]);
                }
                else
                {
                    $buffer .= pack("s", 0);
                }
            }
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            #write out bone map
            $model->{'nodes'}{$i}{'bonemaplocation'} = tell(BMDLOUT);
            $buffer = pack("f*", @{$model->{'nodes'}{$i}{'node2index'}} );
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            #write out QBones
            $buffer = "";
            $model->{'nodes'}{$i}{'qboneslocation'} = tell(BMDLOUT);
            foreach (0..$nodenum - 1)
            {
                $buffer .= pack("f", $model->{'nodes'}{$i}{'QBones'}[$_][0] );
                $buffer .= pack("f", $model->{'nodes'}{$i}{'QBones'}[$_][1] );
                $buffer .= pack("f", $model->{'nodes'}{$i}{'QBones'}[$_][2] );
                $buffer .= pack("f", $model->{'nodes'}{$i}{'QBones'}[$_][3] );
            }
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            #write out TBones
            $buffer = "";
            $model->{'nodes'}{$i}{'tboneslocation'} = tell(BMDLOUT);
            foreach (0..$nodenum - 1)
            {
                $buffer .= pack("f", $model->{'nodes'}{$i}{'TBones'}[$_][0] );
                $buffer .= pack("f", $model->{'nodes'}{$i}{'TBones'}[$_][1] );
                $buffer .= pack("f", $model->{'nodes'}{$i}{'TBones'}[$_][2] );
                #$buffer .= pack("f*", 0,0,0,0,0,0,0,0,0 );
            }
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            #write out unknown array3
            $buffer = "";
            $model->{'nodes'}{$i}{'skinarray3location'} = tell(BMDLOUT);
            foreach (0..$nodenum - 1)
            {
                $buffer .= pack("S", $model->{'nodes'}{$i}{'array8'}{'unpacked'}[($_ * 2)] );
                $buffer .= pack("S", $model->{'nodes'}{$i}{'array8'}{'unpacked'}[($_ * 2) + 1] );
                #$buffer .= pack("f*", 0,0 );
            }
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);
        }
        elsif ($model->{'nodes'}{$i}{'nodetype'} == NODE_SABER) # lightsaber mesh sub-sub-header
        {
            $model->{'nodes'}{$i}{'verts1pointer'} = tell(BMDLOUT);
            $buffer = pack('L', 0); # offset into data
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            $model->{'nodes'}{$i}{'tvertspointer'} = tell(BMDLOUT);
            $buffer = pack('L', 0); # offset into data
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            $model->{'nodes'}{$i}{'tverts1offsetpointer'} = tell(BMDLOUT);
            $buffer = pack('L', 0); # offset into data
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            $buffer = pack('LL', 98, 97); # 87 - 98, 2 values between 1 and 4 apart
            #$buffer .= pack('C[4]', 0, 0, 0, 0); # for lghtsbr and dblsbr
            #$buffer .= pack('C[4]', 235, 219, 57, 185); # for shrtsbr
            #$buffer .= pack('C[4]', -21, -37, 57, -71); # for shrtsbr (signed)
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            # data arrays to write out:
            # vertcoords2 (loc 2)
            $buffer = '';
            $model->{'nodes'}{$i}{'verts1location'} = tell(BMDLOUT);
            foreach(@{$model->{'nodes'}{$i}{'verts1'}}) {
                $buffer .= pack('fff', @{$_});
            }
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

             # data2081-3 (loc 4)
            $buffer = '';
            $model->{'nodes'}{$i}{'tverts1offsetlocation'} = tell(BMDLOUT);
            foreach(@{$model->{'nodes'}{$i}{'tverts1offset'}}) {
                $buffer .= pack('fff', @{$_});
            }
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

             # tverts1offset (loc 3)
            $buffer = '';
            $model->{'nodes'}{$i}{'tvertslocation'} = tell(BMDLOUT);
            foreach(@{$model->{'nodes'}{$i}{'tverts'}}) {
                $buffer .= pack('ff', @{$_});
            }
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);
        }
        elsif ($model->{'nodes'}{$i}{'nodetype'} == NODE_DANGLYMESH)  # dangly mesh sub-sub-header
        {
            $model->{'nodes'}{$i}{'constraintspointer'} = tell(BMDLOUT);
            $buffer = pack("lll", 0, $model->{'nodes'}{$i}{'vertnum'}, $model->{'nodes'}{$i}{'vertnum'} );
            $buffer .= pack("f", $model->{'nodes'}{$i}{'displacement'} );
            $buffer .= pack("f", $model->{'nodes'}{$i}{'tightness'} );
            $buffer .= pack("f", $model->{'nodes'}{$i}{'period'} );
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            $model->{'nodes'}{$i}{'danglyvertspointer'} = tell(BMDLOUT);
            $buffer = pack("l", 0 );
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            # write out dangly mesh constraints
            $buffer = "";
            $model->{'nodes'}{$i}{'constraintslocation'} = tell(BMDLOUT);
            foreach ( @{$model->{'nodes'}{$i}{'constraints'}} )
            {
                $buffer .= pack("f", $_ );
            }
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            # for some reason we now have to write out a duplicate of the vert coords
            $model->{'nodes'}{$i}{'danglyvertslocation'} = tell(BMDLOUT);
            $buffer = "";
            foreach ( @{$model->{'nodes'}{$i}{'verts'}} )
            {
                $buffer .= pack("f*", @{$_} );
            }
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);
        }
        elsif ($model->{'nodes'}{$i}{'nodetype'} == NODE_AABB)  # walk mesh sub-sub-header
        {
            # aabb tree location pointer, (tree immediately following so + 4)
            $buffer = pack("L", ((tell(BMDLOUT) - 12) + 4) );
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);

            # write out advanced aabb tree if it exists
            if (defined($model->{'nodes'}{$i}{'walkmesh'}) &&
                defined($model->{'nodes'}{$i}{'walkmesh'}{aabbs}) &&
                scalar(@{$model->{'nodes'}{$i}{'walkmesh'}{aabbs}}))
            {
                # aabb_start = $totalbytes - 12;
                $buffer = '';
                for my $aabb (@{$model->{'nodes'}{$i}{'walkmesh'}{aabbs}}) {
                    # convert aabb left/right tree indices to offsets using:
                    # start location, index, aabb node size (40)
                    $buffer .= pack(
                        'f[6]LLll', @{$aabb}[0..5],
                        ($aabb->[6] != -1 ? 0 : ($totalbytes - 12) + ($aabb->[9] * 40)),
                        ($aabb->[6] != -1 ? 0 : ($totalbytes - 12) + ($aabb->[10] * 40)),
                        $aabb->[6], $aabb->[8]
                    );
                }
                $totalbytes += length($buffer);
                print (BMDLOUT $buffer);
            }
            # fall back to legacy aabb tree
            else
            {
                $temp1 = tell(BMDLOUT);
                (undef, $buffer) = writeaabb($model, $i, 0, $temp1 );
                seek(BMDLOUT, $buffer, 0);
                $totalbytes += $buffer - $temp1;
            }
        } # end of nodetype == NODE_SKIN sub-sub-header

        # write out the mesh data

        # write out the faces
        $buffer = "";
        $model->{'nodes'}{$i}{'faceslocation'} = tell(BMDLOUT);
        foreach ( @{$model->{'nodes'}{$i}{'Bfaces'}} )
        {
            $buffer .= pack("fffflssssss", @{$_} );
        }
        $totalbytes += length($buffer);
        print (BMDLOUT $buffer);

        # write out the number of vertex indices
        $model->{'nodes'}{$i}{'vertnumlocation'} = tell(BMDLOUT);
        if ($model->{'nodes'}{$i}{'nodetype'} != NODE_SABER) {
            $totalbytes += 4;
            print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'facesnum'} * 3));
        }

        # write out the vert floats
        $buffer = "";
        $model->{'nodes'}{$i}{'vertfloatlocation'} = tell(BMDLOUT);
        if ($model->{'nodes'}{$i}{'nodetype'} != NODE_SABER) {
            foreach ( @{$model->{'nodes'}{$i}{'verts'}} )
            {
                $buffer .= pack("f*", @{$_} );
            }
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);
        }

        # write out the vertex indicies location placeholder
        $model->{'nodes'}{$i}{'vertloclocation'} = tell(BMDLOUT);
        if ($model->{'nodes'}{$i}{'nodetype'} != NODE_SABER) {
            $totalbytes += 4;
            print(BMDLOUT pack("l", 0));
        }

        # write out mesh sequence counter number
        $model->{'nodes'}{$i}{'unknownlocation'} = tell(BMDLOUT);
        if ($model->{'nodes'}{$i}{'nodetype'} != NODE_SABER) {
            $totalbytes += 4;
            print(BMDLOUT pack("L", $model->{'nodes'}{$i}{'array3'}));
        }

        # write out the vert indices
        $buffer = "";
        $model->{'nodes'}{$i}{'vertindicieslocation'} = tell(BMDLOUT);
        if ($model->{'nodes'}{$i}{'nodetype'} != NODE_SABER) {
            foreach ( @{$model->{'nodes'}{$i}{'Bfaces'}} )
            {
                $buffer .= pack("sss", $_->[8], $_->[9], $_->[10] );
            }
            $totalbytes += length($buffer);
            print (BMDLOUT $buffer);
        }
    } # write mesh subheader and data if

    #write out place holders for the child node indexes (if any)
    $model->{'nodes'}{$i}{'childarraylocation'} = tell(BMDLOUT);
    foreach ( 1..$model->{'nodes'}{$i}{'childcount'} )
    {
        print (BMDLOUT pack("L", 0));
        $totalbytes += 4;
    }
    
    #recurse on children, if any
    for my $child ( @{$model->{'nodes'}{$i}{'children'}} )
    {
        $totalbytes = writebinarynode($ref, $child, $totalbytes, $version, $type);
    }


    # $model{'anims'}{$animnum}{'nodes'}{$nodenum}{'Bcontrollers'}{20}{'times'}[$count]
    # $model{'anims'}{$animnum}{'nodes'}{$nodenum}{'Bcontrollers'}{8}{'times'}[$count] = $1;
    # $model{'anims'}{$animnum}{'nodes'}{$nodenum}{'Bcontrollers'}{8}{'values'}[$count] = [$2,$3,$4];

    #write out the controllers and their data (if any)
    $model->{'nodes'}{$i}{'controllerdata'}{'unpacked'} = [];
    $count = 0;
    $buffer = "";

    if ( $model->{'nodes'}{$i}{'controllernum'} > 0 )
    {
        # loop through the controllers and make the controller data list
        foreach $controller (sort {$a <=> $b} keys %{$model->{'nodes'}{$i}{'Bcontrollers'}} )
        {
            # first the time keys
            $timestart = $count;
            foreach ( @{$model->{'nodes'}{$i}{'Bcontrollers'}{$controller}{'times'}} )
            {
                push @{$model->{'nodes'}{$i}{'controllerdata'}{'unpacked'}}, $_;
                $count++;
            }

            # now the values BACK HERE
            $valuestart = $count;
            foreach my $blah ( @{$model->{'nodes'}{$i}{'Bcontrollers'}{$controller}{'values'}} )
            {
                foreach ( @{$blah} )
                {
                    push @{$model->{'nodes'}{$i}{'controllerdata'}{'unpacked'}}, $_;
                    $count++;
                }
            }

            my $ccol = scalar(@{$model->{'nodes'}{$i}{'Bcontrollers'}{$controller}{'values'}[0]});

            # bezier keyed conroller support
            if ($ga eq 'ani' && defined($model->{'nodes'}{$i}{'controllers'}{'bezier'}{$controller}))
            {
                # alter number of columns for bezier keyed controllers now
                $ccol = ($ccol / 3) + 16;
            }

            # Write out controller data, like the chart below:
            #
            # $controller can be one of the following:
            # ========================================
            #
            # 8		Position		All
            # 20	Orientation		All
            # 36	Scaling			All
            #
            # 100	SelfIllumColor		All meshes
            # 128	Alpha			All meshes
            #
            # 76	Color			Light
            # 88	Radius			Light
            # 96	ShadowRadius		Light
            # 100	VerticalDisplacement	Light
            # 140	Multiplier		Light
            #
            # 80	AlphaEnd		Emitter
            # 84	AlphaStart		Emitter
            # 88	BirthRate		Emitter
            # 92	Bounce_Co (-efficient)	Emitter
            # 96	ColorEnd		Emitter
            # 108	ColorStart		Emitter
            # 120	CombineTime		Emitter
            # 124	Drag			Emitter
            # 128	FPS			Emitter
            # 132	FrameEnd		Emitter
            # 136	FrameStart		Emitter
            # 140	Grav			Emitter
            # 144	LifeExp			Emitter
            # 148	Mass			Emitter
            # 152	P2P_Bezier2		Emitter
            # 156	P2P_Bezier3		Emitter
            # 160	ParticleRot (-ation)	Emitter
            # 164	RandVel (-om -ocity)	Emitter
            # 168	SizeStart		Emitter
            # 172	SizeEnd			Emitter
            # 176	SizeStart_Y		Emitter
            # 180	SizeStart_X		Emitter
            # 184	Spread			Emitter
            # 188	Threshold		Emitter
            # 192	Velocity		Emitter
            # 196	XSize			Emitter
            # 200	YSize			Emitter
            # 204	BlurLength		Emitter
            # 208	LightningDelay		Emitter
            # 212	LightningRadius		Emitter
            # 216	LightningScale		Emitter
            # 228	Detonate		Emitter
            # 464	AlphaMid		Emitter
            # 468	ColorMid		Emitter
            # 480	PercentStart		Emitter
            # 481	PercentMid		Emitter
            # 482	PercentEnd		Emitter
            # 484	SizeMid			Emitter
            # 488	SizeMid_Y		Emitter

            if ( $controller == 8 && $ga eq "ani")
            {
                $buffer .= pack("LSSSSCCCC", $controller, 16, $model->{'nodes'}{$i}{'Bcontrollers'}{$controller}{'rows'},
                $timestart, $valuestart, $ccol, 0, 0, 0);
            }
            elsif ( $controller == 20 && $ga eq "ani" )
            {
                if ($ccol == 1) {
                    # this is a compressed quaternion encoded in a single float case
                    $ccol = 2;
                }
                $buffer .= pack("LSSSSCCCC", $controller, 28, $model->{'nodes'}{$i}{'Bcontrollers'}{$controller}{'rows'},
                $timestart, $valuestart, $ccol, 0, 0, 0);
            }
            elsif ( $controller == 8 && $ga eq "geo" )
            {
                $buffer .= pack("LSSSSCCCC", $controller, -1, $model->{'nodes'}{$i}{'Bcontrollers'}{$controller}{'rows'},
                $timestart, $valuestart, $ccol, 87, 73, 0);
            }
            elsif ( $controller == 20 && $ga eq "geo" )
            {
                $buffer .= pack("LSSSSCCCC", $controller, -1, $model->{'nodes'}{$i}{'Bcontrollers'}{$controller}{'rows'},
                $timestart, $valuestart, $ccol, 57, 71, 0);
            }
            elsif ( ($controller == 132 || $controller == 100) && $ga eq "geo" )
            {
                $buffer .= pack("LSSSSCCCC", $controller, -1, $model->{'nodes'}{$i}{'Bcontrollers'}{$controller}{'rows'},
                $timestart, $valuestart, $ccol, 227, 119, 17);
            }
            elsif ( $controller == 36 )
            {
                $buffer .= pack("LSSSSCCCC", $controller, -1, $model->{'nodes'}{$i}{'Bcontrollers'}{$controller}{'rows'},
                $timestart, $valuestart, $ccol, 50, 18, 0); #245, 245, 17);
                # some models have 50, 17, 0... important? TBD
            }
            elsif ( ($model->{'nodes'}{$i}{'nodetype'} == NODE_LIGHT || $ga eq 'geo') &&
                    ($controller == 88 || $controller == 140 || $controller == 76)) # radius, multiplier, color
            {
                $buffer .= pack("LSSSSCCCC", $controller, -1, $model->{'nodes'}{$i}{'Bcontrollers'}{$controller}{'rows'},
                $timestart, $valuestart, $ccol, 255, 114, 17);
            }
            elsif ( $model->{'nodes'}{$i}{'nodetype'} == NODE_EMITTER ) {
                # these numbers are still bad ... need to figure them out for real sometime soon
                $buffer .= pack("LSSSSCCCC", $controller, -1, $model->{'nodes'}{$i}{'Bcontrollers'}{$controller}{'rows'},
                $timestart, $valuestart, $ccol, 99, 121, 17);
            }
            else
            {
                $buffer .= pack("LSSSSCCCC", $controller, -1, $model->{'nodes'}{$i}{'Bcontrollers'}{$controller}{'rows'},
                $timestart, $valuestart, $ccol, 0, 0, 0);
            }
        } # foreach $controller (sort {$a <=> $b} keys %{$model->{'nodes'}{$i}{'Bcontrollers'}} ) {

    # write out the controllers
    $model->{'nodes'}{$i}{'controllerlocation'} = tell(BMDLOUT);
    $totalbytes += length($buffer);
    print (BMDLOUT $buffer);
    # write out the controllers data
    $model->{'nodes'}{$i}{'controllerdatalocation'} = tell(BMDLOUT);
    $buffer = '';
    #$buffer = pack("f*", @{$model->{'nodes'}{$i}{'controllerdata'}{'unpacked'}} );
    # using compressed quaternions in animation makes the following hack necessary!!!
    # basically, the compressed quaternion fits into 4 bytes, but it's not actually a float
    # number. writing it out as a float _will_ cause it to be wrong.
    foreach (@{$model->{'nodes'}{$i}{'controllerdata'}{'unpacked'}}) {
      #if (unpack('f', pack('f', $_)) == $_) {
      #XXX hacks around perl's unfortunate numeric type detection
      # the purpose of this is to not munge the compressed quaternion rotations used in animations
      #XXX this still does not work, disabling it for now
      #if (/\D/ || $_ == 1.0 || $_ == 0.0) {
        $buffer .= pack('f', $_);
      #} else {
      #  $buffer .= pack('L', $_);
      #}
    }
    $totalbytes += length($buffer);
    print (BMDLOUT $buffer);
  } elsif ($model->{'nodes'}{$i}{'controllerdatanum'} > 0 ) {
    $model->{'nodes'}{$i}{'controllerdatalocation'} = tell(BMDLOUT);
    foreach my $blah ( @{$model->{'nodes'}{$i}{'Bcontrollers'}{0}{'values'}} ) {
      push @{$model->{'nodes'}{$i}{'controllerdata'}{'unpacked'}}, $blah;
      $count++;
    }
    $buffer = pack("f*", @{$model->{'nodes'}{$i}{'controllerdata'}{'unpacked'}} );
    $totalbytes += length($buffer);
    print (BMDLOUT $buffer);
  }

  $nodestart = tell(BMDLOUT);

  #fill in all the blanks we left behind
  # fill in header blanks
  if ($model->{'nodes'}{$i}{'childcount'} != 0) {
    seek(BMDLOUT, $model->{'nodes'}{$i}{'childarraypointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'childarraylocation'} - 12));
  }
  # fill in common mesh stuff blanks
  if ($model->{'nodes'}{$i}{'nodetype'} == NODE_TRIMESH || $model->{'nodes'}{$i}{'nodetype'} == NODE_SKIN || $model->{'nodes'}{$i}{'nodetype'} == NODE_DANGLYMESH || $model->{'nodes'}{$i}{'nodetype'} == NODE_AABB) {
    seek(BMDLOUT, $model->{'nodes'}{$i}{'faceslocpointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'faceslocation'} - 12));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'vertnumpointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'vertnumlocation'} - 12));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'vertlocpointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'vertloclocation'} - 12));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'unknownpointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'unknownlocation'} - 12));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'vertfloatpointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'vertfloatlocation'} - 12));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'vertloclocation'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'vertindicieslocation'} - 12));
  }
  # fill in mesh sub-sub-header blanks
  if ($model->{'nodes'}{$i}{'nodetype'} == NODE_SKIN) {  # skin mesh
    seek(BMDLOUT, $model->{'nodes'}{$i}{'bonemaplocpointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'bonemaplocation'} - 12));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'qboneslocpointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'qboneslocation'} - 12));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'tboneslocpointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'tboneslocation'} - 12));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'skinarray3locpointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'skinarray3location'} - 12));
  } elsif ($model->{'nodes'}{$i}{'nodetype'} == NODE_DANGLYMESH) { # dangly mesh
    seek(BMDLOUT, $model->{'nodes'}{$i}{'constraintspointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'constraintslocation'} - 12));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'danglyvertspointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'danglyvertslocation'} - 12));
  } elsif ($model->{'nodes'}{$i}{'nodetype'} == NODE_SABER) { # saber mesh
    seek(BMDLOUT, $model->{'nodes'}{$i}{'faceslocpointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'faceslocation'} - 12));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'vertnumpointer'}, 0);
    print(BMDLOUT pack("L[3]", $model->{'nodes'}{$i}{'vertnumlocation'} - 12, 0, 0));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'vertlocpointer'}, 0);
    print(BMDLOUT pack("L[3]", $model->{'nodes'}{$i}{'vertloclocation'} - 12, 0, 0));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'unknownpointer'}, 0);
    print(BMDLOUT pack("L[3]", $model->{'nodes'}{$i}{'unknownlocation'} - 12, 0, 0));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'vertfloatpointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'vertfloatlocation'} - 12));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'verts1pointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'verts1location'} - 12));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'tverts1offsetpointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'tverts1offsetlocation'} - 12));
    seek(BMDLOUT, $model->{'nodes'}{$i}{'tvertspointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'tvertslocation'} - 12));
  }
  # fill in the controller blanks
  if ( $model->{'nodes'}{$i}{'controllernum'} != 0) {
    seek(BMDLOUT, $model->{'nodes'}{$i}{'controllerpointer'}, 0);
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'controllerlocation'} - 12));
  }
  if ( $model->{'nodes'}{$i}{'controllerdatanum'} != 0) {
    seek(BMDLOUT, $model->{'nodes'}{$i}{'controllerdatapointer'}, 0);    
    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'controllerdatalocation'} - 12));
  }
  #if this is a child of another node fill in the child list for the parent
  if (lc($model->{'nodes'}{$i}{'parent'}) ne "null") {  
    seek(BMDLOUT, $model->{'nodes'}{$model->{'nodes'}{$i}{'parentnodenum'}}{'childarraylocation'} + ($model->{'nodes'}{$i}{'childposition'} * 4), 0);
    if (tell(BMDLOUT) == 0) {
      print("$model->{'nodes'}{$i}{'parent'}\n");
      print("$model->{'nodes'}{$i}{'parentnodenum'}\n");
    }

    print(BMDLOUT pack("l", $model->{'nodes'}{$i}{'header'}{'start'} - 12));
  }
  #print("start+bytes: " . $nodestart . "|" . $totalbytes . "\n");
  seek(BMDLOUT, $nodestart, 0);
    
  return $totalbytes;
}

##################################################
# Write out a raw binary model
# 
sub writerawbinarymdl {
  my ($model, $version) = (@_);
  my ($buffer, $mdxsize, $totalbytes, $nodenum, $work, $nodestart);
  my ($file, $filepath, $timestart, $valuestart, $count);
  my $BMDLOUT;
  my ($temp1, $temp2, $temp3, $temp4, $roffset);
  my $tempref;

  if ($version eq 'k1') {
    # a kotor 1 model
    #$uoffset = -2;  # offset for unpacked values
    $roffset = -8;  # offset for raw bytes
  } elsif ($version eq 'k2') {
    # a kotor 2 model
    #$uoffset = 0;
    $roffset = 0;
  } else {
    return;
  }
  
  $file = $model->{'filename'};
  $filepath = $model->{'filepath+name'};

  $nodenum = $model->{'nodes'}{'truenodenum'};
  open($BMDLOUT, ">", $filepath."-$version-r-bin.mdl") or die "can't open MDL file $filepath-$version-r-bin.mdl\n";
  binmode($BMDLOUT);
  open(BMDXOUT, ">", $filepath."-$version-r-bin.mdx") or die "can't open MDX file $filepath-$version-r-bin.mdx\n";
  binmode(BMDXOUT);
 
  #write out MDX
  seek (BMDXOUT, 0, 0);
  for (my $i = 0; $i < $model->{'nodes'}{'truenodenum'}; $i++) {
    if ( defined($model->{'nodes'}{$i}{'mdxdata'}{'raw'}) ) {
      $model->{'nodes'}{$i}{'mdxstart'} = tell(BMDXOUT);
      print("writing MDX data for node $i at starting location $model->{'nodes'}{$i}{'mdxstart'}\n") if $printall;
      $buffer = $model->{'nodes'}{$i}{'mdxdata'}{'raw'};
      $mdxsize += length($buffer);
      print (BMDXOUT $buffer);
    }
  }
  close BMDXOUT;

  #write out binary MDL
  #write out the file header
  seek ($BMDLOUT, 0, 0);
  $buffer = pack("LLL", 0, 0, $mdxsize);
  $totalbytes += length($buffer);
  print ($BMDLOUT $buffer);

  #write out the geometry header
  $model->{'geoheader'}{'start'} = tell($BMDLOUT);
  $buffer = $model->{'geoheader'}{'raw'};
  $totalbytes += length($buffer);
  print ($BMDLOUT $buffer);
  
  #write out the model header
  $model->{'modelheader'}{'start'} = tell($BMDLOUT);
  $buffer = $model->{'modelheader'}{'raw'};
  $totalbytes += length($buffer);
  print ($BMDLOUT $buffer);

  #write out the name array header
  $model->{'nameheader'}{'start'} = tell($BMDLOUT);
  $buffer = $model->{'nameheader'}{'raw'};
  substr($buffer,  8,  4, pack("l", $mdxsize) );  #replace mdx size with new mdx size
  $totalbytes += length($buffer);
  print ($BMDLOUT $buffer);
  #write out the name array indexes
  $model->{'nameindexes'}{'start'} = tell($BMDLOUT);
  $buffer = $model->{'nameindexes'}{'raw'};
  $totalbytes += length($buffer);
  print ($BMDLOUT $buffer);
  #write out the part names
  $model->{'names'}{'start'} = tell($BMDLOUT);
  $buffer = $model->{'names'}{'raw'};
  $totalbytes += length($buffer);
  print ($BMDLOUT $buffer);

  #write out the animation indexes
  $model->{'anims'}{'indexes'}{'start'} = tell($BMDLOUT);
  $buffer = $model->{'anims'}{'indexes'}{'raw'};
  $totalbytes += length($buffer);
  print ($BMDLOUT $buffer);
  
  #write out the animations (if any)
  for (my $i = 0; $i < $model->{'numanims'}; $i++) {
    #write out the animation geoheader
    $model->{'anims'}{$i}{'geoheader'}{'start'} = tell($BMDLOUT);
    $buffer = $model->{'anims'}{$i}{'geoheader'}{'raw'};
    $totalbytes += length($buffer);
    print ($BMDLOUT $buffer);
    #write out the animation header
    $model->{'anims'}{$i}{'animheader'}{'start'} = tell($BMDLOUT);
    $buffer = $model->{'anims'}{$i}{'animheader'}{'raw'};
    $totalbytes += length($buffer);
    print ($BMDLOUT $buffer);
    #write out the animation events (if any)
    if ( defined($model->{'anims'}{$i}{'animevents'}{'raw'}) ) {
      $model->{'anims'}{$i}{'animevents'}{'start'} = tell($BMDLOUT);
      $buffer = $model->{'anims'}{$i}{'animevents'}{'raw'};
      $totalbytes += length($buffer);
      print ($BMDLOUT $buffer);
    }

    #write out the animation nodes
    #$tempref = $model->{'anims'}{$i}{'nodes'};
    foreach ( sort {$a <=> $b} keys %{$model->{'nodesort'}{$i}} ) {
      #$model->{'nodesort'}{$animnum}{$startnode+12} = $node . "-header";
      ($temp1, $temp2) = split( /-/,$model->{'nodesort'}{$i}{$_} );
      $buffer = $model->{'anims'}{$i}{'nodes'}{$temp1}{$temp2}{'raw'};
      $totalbytes += length($buffer);
      print ($BMDLOUT $buffer);
    }
  } #write out animations for loop

  # write out the nodes
  # in a bioware binary mdl I think they use a recursive function to write
  # the data.  You can tell by how the node controllers and controller data
  # come after the children of the node.  This procedure writes out the
  # data linearly.  Because of this you will never get an exact binary
  # match with a bioware model.  But it seems to work, so I'm gonna leave
  # it as it is.
  #
  # 2016 update: above spells out what was wrong here. now implemented
  #   recursively for closer to exact binary matches.
  $totalbytes += &writerawnodes($BMDLOUT, $model, $roffset);

  #fill in the last blank, the size of the mdl (minus the file header)
  seek($BMDLOUT, 4, 0);
  print($BMDLOUT pack("l", $totalbytes - 12));

  print("$file\n");
  print("done with: $filepath\n");

  close $BMDLOUT;
}


##########################################################
# This is a recursive method to write raw nodes for the replacer.
# Produces more exact binary matches than previous flat iterative approach.
#
sub writerawnodes {
  my ($BMDLOUT, $model, $roffset, $node_index) = @_;

  my ($buffer, $totalbytes);

  $buffer = '';
  $totalbytes = 0;

  if (!defined($node_index)) {
    # root node is nodenum 0 ... not a *great* assumption
    #XXX we can get the rootnode location, maybe search for it by start location
    $node_index = 0;
  }

  # assume caller has left the file seeked to where we should write the node
  my $nodestart = tell($BMDLOUT);

  #write out the node header
  $model->{'nodes'}{$node_index}{'header'}{'start'} = $nodestart;
  $buffer = $model->{'nodes'}{$node_index}{'header'}{'raw'};
  $totalbytes += length($buffer);
  print($BMDLOUT $buffer);

  #write out the sub header, sub-sub-header, and data (if any)
  if ( defined( $model->{'nodes'}{$node_index}{'subhead'}{'raw'} ) ) {
    # write out the node header
    $model->{'nodes'}{$node_index}{'subhead'}{'start'} = tell($BMDLOUT);
    $buffer = $model->{'nodes'}{$node_index}{'subhead'}{'raw'};
    $totalbytes += length($buffer);
    print($BMDLOUT $buffer);

    # write out node specific data for mesh nodes
    if ($model->{'nodes'}{$node_index}{'nodetype'} & NODE_HAS_MESH) {
      # write out mesh type specific data
      if ($model->{'nodes'}{$node_index}{'nodetype'} & NODE_HAS_SABER) { # node type 2081 I call it saber mesh
        # write out a copy of the vertex coordinates
        $model->{'nodes'}{$node_index}{'vertcoords2'}{'start'} = tell($BMDLOUT);
        print("$node_index-vertcoords2: $model->{'nodes'}{$node_index}{'vertcoords2'}{'start'}\n") if $printall;
        $buffer = $model->{'nodes'}{$node_index}{'vertcoords2'}{'raw'};
        $totalbytes += length($buffer);
        print ($BMDLOUT $buffer);

        # write out the node type 2081 data (what is this?)
        $model->{'nodes'}{$node_index}{'data2081-3'}{'start'} = tell($BMDLOUT);
        print("$node_index-data2081-3: $model->{'nodes'}{$node_index}{'data2081-3'}{'start'}\n") if $printall;
        $buffer = $model->{'nodes'}{$node_index}{'data2081-3'}{'raw'};
        $totalbytes += length($buffer);
        print ($BMDLOUT $buffer);

        # write out the tverts+
        $model->{'nodes'}{$node_index}{'tverts+'}{'start'} = tell($BMDLOUT);
        print("$node_index-tverts+: $model->{'nodes'}{$node_index}{'tverts+'}{'start'}\n") if $printall;
        $buffer = $model->{'nodes'}{$node_index}{'tverts+'}{'raw'};
        $totalbytes += length($buffer);
        print ($BMDLOUT $buffer);
      } elsif ($model->{'nodes'}{$node_index}{'nodetype'} & NODE_HAS_SKIN) { # skin mesh
        # write out the bone map
        $model->{'nodes'}{$node_index}{'bonemap'}{'start'} = tell($BMDLOUT);
        $buffer = $model->{'nodes'}{$node_index}{'bonemap'}{'raw'};
        $totalbytes += length($buffer);
        print ($BMDLOUT $buffer);

        # write out the qbones
        $model->{'nodes'}{$node_index}{'qbones'}{'start'} = tell($BMDLOUT);
        $buffer = $model->{'nodes'}{$node_index}{'qbones'}{'raw'};
        $totalbytes += length($buffer);
        print ($BMDLOUT $buffer);

        # write out the tbones
        $model->{'nodes'}{$node_index}{'tbones'}{'start'} = tell($BMDLOUT);
        $buffer = $model->{'nodes'}{$node_index}{'tbones'}{'raw'};
        $totalbytes += length($buffer);
        print ($BMDLOUT $buffer);

        # write out unknown array 8
        $model->{'nodes'}{$node_index}{'array8'}{'start'} = tell($BMDLOUT);
        $buffer = $model->{'nodes'}{$node_index}{'array8'}{'raw'};
        $totalbytes += length($buffer);
        print ($BMDLOUT $buffer);
      } elsif ($model->{'nodes'}{$node_index}{'nodetype'} & NODE_HAS_DANGLY) { # dangly mesh
        # write out dangly constraints
        $model->{'nodes'}{$node_index}{'constraints+'}{'start'} = tell($BMDLOUT);
        $buffer = $model->{'nodes'}{$node_index}{'constraints+'}{'raw'};
        $totalbytes += length($buffer);
        print ($BMDLOUT $buffer);
      }

      # write out the faces
      $model->{'nodes'}{$node_index}{'faces'}{'start'} = tell($BMDLOUT);
      $buffer = $model->{'nodes'}{$node_index}{'faces'}{'raw'};
      $totalbytes += length($buffer);
      print ($BMDLOUT $buffer);

      if (!($model->{'nodes'}{$node_index}{'nodetype'} & NODE_HAS_SABER)) {
        # write out the pointer to the array that holds the number of vert indices
        $model->{'nodes'}{$node_index}{'pntr_to_vert_num'}{'start'} = tell($BMDLOUT);
        $buffer = $model->{'nodes'}{$node_index}{'pntr_to_vert_num'}{'raw'};
        $totalbytes += length($buffer);
        print ($BMDLOUT $buffer);
      }

      # write out the vertex coordinates
      $model->{'nodes'}{$node_index}{'vertcoords'}{'start'} = tell($BMDLOUT);
      $buffer = $model->{'nodes'}{$node_index}{'vertcoords'}{'raw'};
      $totalbytes += length($buffer);
      print ($BMDLOUT $buffer);

      if (!($model->{'nodes'}{$node_index}{'nodetype'} & NODE_HAS_SABER)) {
        # write out the pointer to the array that holds the location of the vert indices
        $model->{'nodes'}{$node_index}{'pntr_to_vert_loc'}{'start'} = tell($BMDLOUT);
        $buffer = pack("l", (tell($BMDLOUT) + 8) - 12);
        $totalbytes += length($buffer);
        print ($BMDLOUT $buffer);

        # write out mesh sequence counter array that always has 1 element
        $model->{'nodes'}{$node_index}{'array3'}{'start'} = tell($BMDLOUT);
        $buffer = $model->{'nodes'}{$node_index}{'array3'}{'raw'};
        $totalbytes += length($buffer);
        print ($BMDLOUT $buffer);

        # write out the vert indices
        $model->{'nodes'}{$node_index}{'vertindexes'}{'start'} = tell($BMDLOUT);
        $buffer = $model->{'nodes'}{$node_index}{'vertindexes'}{'raw'};
        $totalbytes += length($buffer);
        print ($BMDLOUT $buffer);
      } # {'nodetype'} != 2081
    } # ($nodetype & NODE_HAS_MESH) if
  } # write subheader, sub-subheader, and data if

  #write out child node indexes (if any)
  if ( $model->{'nodes'}{$node_index}{'childcount'} != 0 ) {
    $model->{'nodes'}{$node_index}{'childcounter'} = 0;
    $model->{'nodes'}{$node_index}{'childindexes'}{'start'} = tell($BMDLOUT);
    $buffer = $model->{'nodes'}{$node_index}{'childindexes'}{'raw'};
    $totalbytes += length($buffer);
    print ($BMDLOUT $buffer);

    #write out child nodes
    my $childbytes = 0;
    # record position where child(ren) begin
    $nodestart = tell($BMDLOUT);
    for my $child_index (@{$model->{'nodes'}{$node_index}{'childindexes'}{'nums'}}) {
      # record size of child and maybe its children
      $childbytes += &writerawnodes($BMDLOUT, $model, $roffset, $child_index);
      # every child that is written seeks to its pointers as last activity,
      # therefore we seek to just after the written child(ren) after write
      seek($BMDLOUT, $nodestart + $childbytes, 0);
    }
    $totalbytes += $childbytes;
  }

  # write out the controllers
  $model->{'nodes'}{$node_index}{'controllers'}{'start'} = tell($BMDLOUT);
  $buffer = $model->{'nodes'}{$node_index}{'controllers'}{'raw'};
  $totalbytes += length($buffer);
  print ($BMDLOUT $buffer);

  # write out the controllers data
  $model->{'nodes'}{$node_index}{'controllerdata'}{'start'} = tell($BMDLOUT);
  $buffer = $model->{'nodes'}{$node_index}{'controllerdata'}{'raw'};
  $totalbytes += length($buffer);
  print ($BMDLOUT $buffer);

  # go back and change all the pointers
  # write in the header blanks
  # location of this nodes parent
  if ($node_index != 0) {
    seek($BMDLOUT, $model->{'nodes'}{$node_index}{'header'}{'start'} + 12, 0);
    print($BMDLOUT pack("l", $model->{'nodes'}{ $model->{'nodes'}{$node_index}{'parentnodenum'} }{'header'}{'start'} - 12));
  } else {
    seek($BMDLOUT, $model->{'nodes'}{$node_index}{'header'}{'start'} + 12, 0);
    print($BMDLOUT pack("l", 0));
  }
  if ($model->{'nodes'}{$node_index}{'childcount'} != 0) {
    # pointer to the child array
    seek($BMDLOUT, $model->{'nodes'}{$node_index}{'header'}{'start'} + 44, 0);
    print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'childindexes'}{'start'} - 12));
  }
  # fill in mesh stuff blanks
  if ($model->{'nodes'}{$node_index}{'nodetype'} & NODE_HAS_MESH) {
    if ($model->{'nodes'}{$node_index}{'nodetype'} & NODE_HAS_SABER) {
      seek($BMDLOUT, $model->{'nodes'}{$node_index}{'subhead'}{'start'} + 340 + $roffset, 0); #
      print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'vertcoords2'}{'start'} - 12));
      seek($BMDLOUT, $model->{'nodes'}{$node_index}{'subhead'}{'start'} + 344 + $roffset, 0); #
      print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'tverts+'}{'start'} - 12));
      seek($BMDLOUT, $model->{'nodes'}{$node_index}{'subhead'}{'start'} + 348 + $roffset, 0); #
      print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'data2081-3'}{'start'} - 12));
    } elsif ($model->{'nodes'}{$node_index}{'nodetype'} & NODE_HAS_SKIN) {
      seek($BMDLOUT, $model->{'nodes'}{$node_index}{'subhead'}{'start'} + 360 + $roffset, 0); #
      print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'bonemap'}{'start'} - 12));
      seek($BMDLOUT, $model->{'nodes'}{$node_index}{'subhead'}{'start'} + 368 + $roffset, 0); #
      print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'qbones'}{'start'} - 12));
      seek($BMDLOUT, $model->{'nodes'}{$node_index}{'subhead'}{'start'} + 380 + $roffset, 0); #
      print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'tbones'}{'start'} - 12));
      seek($BMDLOUT, $model->{'nodes'}{$node_index}{'subhead'}{'start'} + 392 + $roffset, 0); #
      print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'array8'}{'start'} - 12));
    } elsif ($model->{'nodes'}{$node_index}{'nodetype'} & NODE_HAS_DANGLY) {
      seek($BMDLOUT, $model->{'nodes'}{$node_index}{'subhead'}{'start'} + 340 + $roffset, 0); #
      print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'constraints+'}{'start'} - 12));
    }

    seek($BMDLOUT, $model->{'nodes'}{$node_index}{'subhead'}{'start'} + 8, 0);
    print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'faces'}{'start'} - 12));

    if (!($model->{'nodes'}{$node_index}{'nodetype'} & NODE_HAS_SABER)) {
      seek($BMDLOUT, $model->{'nodes'}{$node_index}{'subhead'}{'start'} + 176, 0);
      print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'pntr_to_vert_num'}{'start'} - 12));
      seek($BMDLOUT, $model->{'nodes'}{$node_index}{'subhead'}{'start'} + 188, 0);
      print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'pntr_to_vert_loc'}{'start'} - 12));
      seek($BMDLOUT, $model->{'nodes'}{$node_index}{'subhead'}{'start'} + 200, 0);
      print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'array3'}{'start'} - 12));
      seek($BMDLOUT, $model->{'nodes'}{$node_index}{'subhead'}{'start'} + 332 + $roffset, 0); #
      print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'mdxstart'}));
    }

    seek($BMDLOUT, $model->{'nodes'}{$node_index}{'subhead'}{'start'} + 336 + $roffset, 0); #
    print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'vertcoords'}{'start'} - 12));
  } # ($model->{'nodes'}{$node_index}{'nodetype'} & NODE_HAS_MESH)

  # fill in the controller blanks
  if ( $model->{'nodes'}{$node_index}{'controllernum'} != 0) {
    seek($BMDLOUT, $model->{'nodes'}{$node_index}{'header'}{'start'} + 56, 0);
    print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'controllers'}{'start'} - 12));
    seek($BMDLOUT, $model->{'nodes'}{$node_index}{'header'}{'start'} + 68, 0);
    print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'controllerdata'}{'start'} - 12));
  }

  #if this is a child of another node fill in the child list for the parent
  if (lc($model->{'nodes'}{$node_index}{'parent'}) ne "null") {
    my $temp1;
    $temp1 =  $model->{'nodes'}{ $model->{'nodes'}{$node_index}{'parentnodenum'} }{'childindexes'}{'start'};
    $temp1 += $model->{'nodes'}{ $model->{'nodes'}{$node_index}{'parentnodenum'} }{'childcounter'} * 4;
    seek($BMDLOUT, $temp1, 0);
    $model->{'nodes'}{ $model->{'nodes'}{$node_index}{'parentnodenum'} }{'childcounter'}++;
    if (tell($BMDLOUT) == 0) {
      print("$model->{'nodes'}{$node_index}{'parentnodenum'}\n");
      print("$model->{'nodes'}{ $model->{'nodes'}{$node_index}{'parentnodenum'} }{'childindexes'}{'start'}\n");
      print("$model->{'nodes'}{ $model->{'nodes'}{$node_index}{'parentnodenum'} }{'childcounter'}\n");
      print("$model->{'nodes'}{$node_index}{'parent'}\n");
    }
    print($BMDLOUT pack("l", $model->{'nodes'}{$node_index}{'header'}{'start'} - 12));
  }

  return $totalbytes;
}


##########################################################
# This takes data from an ascii source and makes it look
# like it is from a binary source (as best as we can at the moment).
#
sub replaceraw {
  my ($binarymodel, $asciimodel, $binarynodename, $asciinodename) = (@_);
  my ($buffer, $binarynode, $asciinode, $item);  
  my ($count, $timestart, $valuestart, $work);

  $binarynode = $binarymodel->{'nodeindex'}{lc($binarynodename)};
  $asciinode = $asciimodel->{'nodeindex'}{lc($asciinodename)};

  print("$binarynode - $binarynodename\n");
  print("$asciinode - $asciinodename\n");

  print("$asciimodel->{'nodes'}{$asciinode}{'mdxdatasize'}\n") if $printall;
  # replace the MDX data
  $buffer = "";
  # build the raw mdx data from the ascii model
  for (my $j = 0; $j < $asciimodel->{'nodes'}{$asciinode}{'vertnum'}; $j++) {
    $buffer .= pack("f",$asciimodel->{'nodes'}{$asciinode}{'verts'}[$j][0]);
    $buffer .= pack("f",$asciimodel->{'nodes'}{$asciinode}{'verts'}[$j][1]);
    $buffer .= pack("f",$asciimodel->{'nodes'}{$asciinode}{'verts'}[$j][2]);
    $buffer .= pack("f",$asciimodel->{'nodes'}{$asciinode}{'vertexnormals'}{$j}[0]);
    $buffer .= pack("f",$asciimodel->{'nodes'}{$asciinode}{'vertexnormals'}{$j}[1]);
    $buffer .= pack("f",$asciimodel->{'nodes'}{$asciinode}{'vertexnormals'}{$j}[2]);
    # if this mesh has uv coordinates add them in
    if ($asciimodel->{'nodes'}{$asciinode}{'mdxdatasize'} > 24) {
      $buffer .= pack("f",$asciimodel->{'nodes'}{$asciinode}{'tverts'}[$asciimodel->{'nodes'}{$asciinode}{'tverti'}{$j}][0]);
      $buffer .= pack("f",$asciimodel->{'nodes'}{$asciinode}{'tverts'}[$asciimodel->{'nodes'}{$asciinode}{'tverti'}{$j}][1]);
    }
    # if this is a skin mesh node then add in the bone weights
    if ($asciimodel->{'nodes'}{$asciinode}{'nodetype'} == NODE_SKIN) {
      $buffer .= pack("f*", @{$asciimodel->{'nodes'}{$asciinode}{'Bbones'}[$j]} );
    }
  }
  # add on the end padding
  # this should actually be enforcing 32-byte alignment i think, but it isn't.
  # it gets lucky most of the time though (wouldn't work replacing untextured mesh probably)
  if ($asciimodel->{'nodes'}{$asciinode}{'nodetype'} == NODE_SKIN) {
    # padding for skin nodes seems to be different, more like this:
    $buffer .= pack("f*", 1000000, 1000000, 1000000, 0,
                          0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0);
  } else {
    $buffer .= pack("f*", 10000000, 10000000, 10000000, 0,
                          0, 0, 0, 0);
  }
  # write the mdx data to the binary model
  $binarymodel->{'nodes'}{$binarynode}{'mdxdata'}{'raw'} = $buffer;
  
  # replace the node header
  # get the raw data from the binary model
  $buffer = $binarymodel->{'nodes'}{$binarynode}{'header'}{'raw'};
  # replace parts of the raw data from the binary model with data from the ascii model

  substr($buffer, 16, 4, pack("f", $asciimodel->{'nodes'}{$asciinode}{'Bcontrollers'}{8}{'values'}[0][0]) ); # x
  substr($buffer, 20, 4, pack("f", $asciimodel->{'nodes'}{$asciinode}{'Bcontrollers'}{8}{'values'}[0][1]) ); # y
  substr($buffer, 24, 4, pack("f", $asciimodel->{'nodes'}{$asciinode}{'Bcontrollers'}{8}{'values'}[0][2]) ); # z
  substr($buffer, 28, 4, pack("f", $asciimodel->{'nodes'}{$asciinode}{'Bcontrollers'}{20}{'values'}[0][3]) ); # w
  substr($buffer, 32, 4, pack("f", $asciimodel->{'nodes'}{$asciinode}{'Bcontrollers'}{20}{'values'}[0][0]) ); # x
  substr($buffer, 36, 4, pack("f", $asciimodel->{'nodes'}{$asciinode}{'Bcontrollers'}{20}{'values'}[0][1]) ); # y
  substr($buffer, 40, 4, pack("f", $asciimodel->{'nodes'}{$asciinode}{'Bcontrollers'}{20}{'values'}[0][2]) ); # z

  substr($buffer, 60, 4, pack("l", $asciimodel->{'nodes'}{$asciinode}{'controllernum'}) );
  substr($buffer, 64, 4, pack("l", $asciimodel->{'nodes'}{$asciinode}{'controllernum'}) );
   
  substr($buffer, 72, 4, pack("l", $asciimodel->{'nodes'}{$asciinode}{'controllerdatanum'}) );
  substr($buffer, 76, 4, pack("l", $asciimodel->{'nodes'}{$asciinode}{'controllerdatanum'}) );
  # write the raw data back to the binary model
  $binarymodel->{'nodes'}{$binarynode}{'header'}{'raw'} = $buffer;

  # replace controllers and their data
  $binarymodel->{'nodes'}{$binarynode}{'controllerdata'}{'unpacked'} = [];
  $count = 0;
  $buffer = "";
  # loop through the controllers and make the controller data list
  foreach $work (sort {$a <=> $b} keys %{$asciimodel->{'nodes'}{$asciinode}{'Bcontrollers'}} ) {
    # first the time keys
    $timestart = $count;
    foreach ( @{$asciimodel->{'nodes'}{$asciinode}{'Bcontrollers'}{$work}{'times'}} ) {
      push @{$binarymodel->{'nodes'}{$binarynode}{'controllerdata'}{'unpacked'}}, $_;
      $count++;
    }
    # now the values FIXING
    $valuestart = $count;
    foreach my $blah ( @{$asciimodel->{'nodes'}{$asciinode}{'Bcontrollers'}{$work}{'values'}} ) {
      foreach ( @{$blah} ) {
        push @{$binarymodel->{'nodes'}{$binarynode}{'controllerdata'}{'unpacked'}}, $_;
        $count++;
      }
    }
    $buffer .= pack("LSSSSCCCC", $work, -1, 1, $timestart, $valuestart, scalar(@{$asciimodel->{'nodes'}{$asciinode}{'Bcontrollers'}{$work}{'values'}[0]}), 0, 0, 0);
  }

  # write out the controllers
  $binarymodel->{'nodes'}{$binarynode}{'controllers'}{'raw'} = $buffer;
  # write out the controllers data
  $buffer = pack("f*", @{$binarymodel->{'nodes'}{$binarynode}{'controllerdata'}{'unpacked'}} );
  $binarymodel->{'nodes'}{$binarynode}{'controllerdata'}{'raw'} = $buffer;

  # replace mesh header
  # get the raw data from the binary model
  $buffer = $binarymodel->{'nodes'}{$binarynode}{'subhead'}{'raw'};
  # replace parts of the raw data from the binary model with data from the ascii model
  substr($buffer,  12,  4, pack("l", $asciimodel->{'nodes'}{$asciinode}{'facesnum'}) );
  substr($buffer,  16,  4, pack("l", $asciimodel->{'nodes'}{$asciinode}{'facesnum'}) );
  substr($buffer,  60,  4, pack("f", $asciimodel->{'nodes'}{$asciinode}{'diffuse'}[0]) );
  substr($buffer,  64,  4, pack("f", $asciimodel->{'nodes'}{$asciinode}{'diffuse'}[1]) );
  substr($buffer,  68,  4, pack("f", $asciimodel->{'nodes'}{$asciinode}{'diffuse'}[2]) );
  substr($buffer,  72,  4, pack("f", $asciimodel->{'nodes'}{$asciinode}{'ambient'}[0]) );
  substr($buffer,  76,  4, pack("f", $asciimodel->{'nodes'}{$asciinode}{'ambient'}[1]) );
  substr($buffer,  80,  4, pack("f", $asciimodel->{'nodes'}{$asciinode}{'ambient'}[2]) );
  substr($buffer,  88, 32, pack("Z[32]", $asciimodel->{'nodes'}{$asciinode}{'bitmap'}) );
  substr($buffer, 120, 32, pack("Z[32]", $asciimodel->{'nodes'}{$asciinode}{'bitmap2'}) );
  substr($buffer, 252,  4, pack("l", $asciimodel->{'nodes'}{$asciinode}{'mdxdatasize'}) );
  if ($asciimodel->{'nodes'}{$asciinode}{'mdxdatasize'} > 24) {
    substr($buffer, 272, 4, pack("l", 24) );  # texture data offset
    substr($buffer, 306, 2, pack("s", 1) );   # number of textures
  } else {
    substr($buffer, 272, 4, pack("l", -1) );  # texture data offset
    substr($buffer, 306, 2, pack("s", 0) );   # number of textures
  }
  substr($buffer, 304, 2, pack("s", $asciimodel->{'nodes'}{$asciinode}{'vertnum'}) );
  if ($asciimodel->{'nodes'}{$asciinode}{'shadow'} == 1) {
    substr($buffer, 310, 2, pack("s", 256) );
  } else {
    substr($buffer, 310, 2, pack("s", 0) );
  }
  if ($asciimodel->{'nodes'}{$asciinode}{'render'} == 1) {
    substr($buffer, 312, 2, pack("s", 256) );
  } else {
    substr($buffer, 312, 2, pack("s", 0) );
  }
  # write the raw data back to the binary model
  $binarymodel->{'nodes'}{$binarynode}{'subhead'}{'raw'} = $buffer;

  # replace the face array
  $buffer = "";
  foreach ( @{$asciimodel->{'nodes'}{$asciinode}{'Bfaces'}} ) {
    $buffer .= pack("fffflssssss", @{$_} );
  }
  $binarymodel->{'nodes'}{$binarynode}{'faces'}{'raw'} = $buffer;

  # replace vertex coordinates
  $buffer = "";
  foreach ( @{$asciimodel->{'nodes'}{$asciinode}{'verts'}} ) {
    $buffer .= pack("f*", @{$_} );
  }
  $binarymodel->{'nodes'}{$binarynode}{'vertcoords'}{'raw'} = $buffer;
  
  # replace vertex indexes
  $buffer = "";
  foreach ( @{$asciimodel->{'nodes'}{$asciinode}{'Bfaces'}} ) {
    $buffer .= pack("sss", $_->[8], $_->[9], $_->[10] );
  }
  $binarymodel->{'nodes'}{$binarynode}{'vertindexes'}{'raw'} = $buffer;
  $binarymodel->{'nodes'}{$binarynode}{'pntr_to_vert_num'}{'raw'} = pack("l", $asciimodel->{'nodes'}{$asciinode}{'facesnum'} * 3);
}

##########################################################
# This builds a tree list with the model data.
# Only works for models from binary source right now
# 
sub buildtree {
  my ($tree, $model) = (@_);
  my $temp;

  if ($model->{'source'} eq "ascii") {
    print("Model from ascii source\n");
    return;
  }

  #empty out the tree list
  $tree->delete('all');

  $tree->add('.', 
       -text => $model->{'filename'},
             -data => $model);
  
  # add the basic stuff that is in every model
  $tree->add('.geoheader', 
             -text => "geo_header ($model->{'geoheader'}{'start'})",
             -data => 1);
  $tree->add('.modelheader', 
             -text => "model_header ($model->{'modelheader'}{'start'})",
             -data => 1);
  $tree->add('.namearray', 
             -text => 'Name_array',
             -data => 1);
  $tree->add('.namearray.nameheader', 
             -text => "name_header ($model->{'nameheader'}{'start'})",
             -data => 1);
  $tree->add('.namearray.nameindexes', 
             -text => "name_indexes ($model->{'nameindexes'}{'start'})",
             -data => 1);
  $tree->add('.namearray.partnames', 
             -text => "names ($model->{'names'}{'start'})",
             -data => 1);
  $tree->setmode(".namearray", "close");
  $tree->close(".namearray");
  
  # add the animations (if any)
  if ($model->{'numanims'} != 0) {
    # make the animation root
    $tree->add('.anims', -text => "Animations");
    $tree->add('.anims.indexes', 
               -text => "anim_indexes ($model->{'anims'}{'indexes'}{'start'})",
               -data => 1);
    # loop through the animations
    for (my $i = 0; $i < $model->{'numanims'}; $i++) {
      $tree->add(".anims.$i", 
                 -text => $model->{'anims'}{$i}{'name'},
                 -data => 1);
      $tree->add(".anims.$i.geoheader", 
                 -text => "anim_geoheader ($model->{'anims'}{$i}{'geoheader'}{'start'})",
                 -data => 1);
      $tree->add(".anims.$i.animheader", 
                 -text => "anim_header ($model->{'anims'}{$i}{'animheader'}{'start'})",
                 -data => 1);
      # if this animation has events then add an entry for them
      if ($model->{'anims'}{$i}{'eventsnum'} != 0) {
        $tree->add(".anims.$i.animevents", 
                   -text => "anim_events ($model->{'anims'}{$i}{'animevents'}{'start'})",
                   -data => 1);
      }
      # loop through the nodes for this animation
      $tree->add(".anims.$i.nodes", 
                 -text => "nodes",
                 -data => 1);
      foreach (sort {$a <=> $b} keys(%{$model->{'anims'}{$i}{'nodes'}}) ) {
  if ($_ eq 'truenodenum') {next;};
        $tree->add(".anims.$i.nodes.$_", 
                   -text => "<$model->{'anims'}{$i}{'nodes'}{$_}{'nodetype'}> $_-$model->{'partnames'}[$_] <$model->{'anims'}{$i}{'nodes'}{$_}{'parent'}>",
                   -data => 1);
        $tree->add(".anims.$i.nodes.$_.header", 
                   -text => "header ($model->{'anims'}{$i}{'nodes'}{$_}{'header'}{'start'})",
                   -data => 1);
  # if the node has children make an entry
        if ($model->{'anims'}{$i}{'nodes'}{$_}{'childcount'} != 0) {
          $tree->add(".anims.$i.nodes.$_.childindexes", 
                     -text => "children ($model->{'anims'}{$i}{'nodes'}{$_}{'childindexes'}{'start'})",
                     -data => 9);
        }
  # if the node has controllers make entries for them and their data
        if ($model->{'anims'}{$i}{'nodes'}{$_}{'controllernum'} != 0) {
          $tree->add(".anims.$i.nodes.$_.controllers", 
                     -text => "controllers ($model->{'anims'}{$i}{'nodes'}{$_}{'controllers'}{'start'})",
                     -data => 9);
          $tree->add(".anims.$i.nodes.$_.controllerdata", 
                     -text => "controllerdata ($model->{'anims'}{$i}{'nodes'}{$_}{'controllerdata'}{'start'})",
                     -data => 1);
  }
  # make the branch closeable and close it
        $tree->setmode(".anims.$i.nodes.$_", "close");
        $tree->close(".anims.$i.nodes.$_");
      } # for each loop
      # make the branch closeable and close it
      $tree->setmode(".anims.$i.nodes", "close");
      $tree->close(".anims.$i.nodes");
      
      # make the branch closeable and close it
      $tree->setmode(".anims.$i", "close");
      $tree->close(".anims.$i");
    } # for loop
    # make the branch closeable and close it
    $tree->setmode(".anims", "close");
    $tree->close(".anims");
  } # animations if

  # create the node root
  $tree->add('.nodes', 
             -text => "nodes",
             -data => 1);
  # loop through the geometry nodes
  for (my $i = 0; $i < $model->{'nodes'}{'truenodenum'}; $i++) {
    $tree->add(".nodes.$i", 
               -text => "<$model->{'nodes'}{$i}{'nodetype'}> $i-$model->{'partnames'}[$i] <$model->{'nodes'}{$i}{'parent'}>",
               -data => 1);
    $tree->add(".nodes.$i.header", 
               -text => "node_header_$model->{'nodes'}{$i}{'nodetype'} ($model->{'nodes'}{$i}{'header'}{'start'})",
               -data => 1);
    # if this node has controllers make entries for them and their data
    if ($model->{'nodes'}{$i}{'controllernum'} != 0) {
      $tree->add(".nodes.$i.header.controllers", 
                 -text => "controllers ($model->{'nodes'}{$i}{'controllers'}{'start'})",
                 -data => 9);
      $tree->add(".nodes.$i.header.controllerdata", 
                 -text => "controller_data  ($model->{'nodes'}{$i}{'controllerdata'}{'start'})",
                 -data => 1);
    }
    # if this node has children make an entry for it
    if ($model->{'nodes'}{$i}{'childcount'} != 0) {
      $tree->add(".nodes.$i.header.childindexes", 
                 -text => "node_children ($model->{'nodes'}{$i}{'childindexes'}{'start'})",
                 -data => 1);
    }
    # if this node has a subheader make an entry for it
    if ($model->{'nodes'}{$i}{'nodetype'} != NODE_DUMMY) {
      $tree->add(".nodes.$i.subhead", 
                 -text => "subhead",
                 -data => 1);
    }
    # now we take care of specific node types
    # nodes with trimesh, nodetypes = 33, 97, 289, 2081
    if ($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_MESH) {
      $tree->add(".nodes.$i.subhead.faces", 
                 -text => "faces  ($model->{'nodes'}{$i}{'faces'}{'start'})",
                 -data => 11);
      if (!($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_SABER)) { # unknown node type 2081, I call it saber mesh
        $tree->add(".nodes.$i.subhead.vertcoords", 
                   -text => "vertcoords ($model->{'nodes'}{$i}{'vertcoords'}{'start'})",
                   -data => 3);
        $tree->add(".nodes.$i.subhead.pntr_to_vert_num", 
                   -text => "pntr_to_vert_num ($model->{'nodes'}{$i}{'pntr_to_vert_num'}{'start'})",
                   -data => 1);
        $tree->add(".nodes.$i.subhead.pntr_to_vert_loc", 
                   -text => "pntr_to_vert_loc ($model->{'nodes'}{$i}{'pntr_to_vert_loc'}{'start'})",
                   -data => 1);
        $tree->add(".nodes.$i.subhead.array3", 
                   -text => "array3 ($model->{'nodes'}{$i}{'array3'}{'start'})",
                   -data => 1);
        $tree->add(".nodes.$i.subhead.vertindexes", 
                   -text => "vertindexes ($model->{'nodes'}{$i}{'vertindexes'}{'start'})",
                   -data => 3);
      }
    }    
    if ($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_SKIN) { # node type 97 = skin mesh
      $tree->add(".nodes.$i.subhead.bonemap", 
                 -text => "bonemap ($model->{'nodes'}{$i}{'bonemap'}{'start'})",
                 -data => 1);
      $tree->add(".nodes.$i.subhead.qbones", 
                 -text => "qbones ($model->{'nodes'}{$i}{'qbones'}{'start'})",
                 -data => 4);
      $tree->add(".nodes.$i.subhead.tbones", 
                 -text => "tbones ($model->{'nodes'}{$i}{'tbones'}{'start'})",
                 -data => 3);
      $tree->add(".nodes.$i.subhead.array8", 
                 -text => "array8 ($model->{'nodes'}{$i}{'array8'}{'start'})",
                 -data => 2);
    } elsif ($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_DANGLY) { # node type 289 = dangly mesh
      $tree->add(".nodes.$i.subhead.constraints+", 
                 -text => "constraints+ ($model->{'nodes'}{$i}{'constraints+'}{'start'})",
                 -data => 1);
    } elsif ($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_AABB) { # node type 545 = aabb
      $tree->add(".nodes.$i.subhead.aabb", 
                 -text => "aabb ($model->{'nodes'}{$i}{'aabb'}{'start'})",
                 -data => 10);
    } elsif ($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_SABER) { # unknown node type 2081, I call it saber mesh
      $tree->add(".nodes.$i.subhead.vertcoords", 
                 -text => "vertcoords ($model->{'nodes'}{$i}{'vertcoords'}{'start'})",
                 -data => 3);
      $tree->add(".nodes.$i.subhead.vertcoords2", 
                 -text => "vertcoords2 ($model->{'nodes'}{$i}{'vertcoords2'}{'start'})",
                 -data => 3);
      $tree->add(".nodes.$i.subhead.tverts+", 
                 -text => "tverts+ ($model->{'nodes'}{$i}{'tverts+'}{'start'})",
                 -data => 2);
      $tree->add(".nodes.$i.subhead.data2081-3", 
                 -text => "data2081-3 ($model->{'nodes'}{$i}{'data2081-3'}{'start'})",
                 -data => 2);
    }
    # if node has mdx data add entry for it.  2081 is a mesh, but has no mdx data!
    if (($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_MESH) && !($model->{'nodes'}{$i}{'nodetype'} & NODE_HAS_SABER)) {
      $tree->add(".nodes.$i.subhead.mdxdata", 
                 -text => "mdxdata {$model->{'nodes'}{$i}{'mdxdata'}{'start'}}",
                 -data => $model->{'nodes'}{$i}{'mdxdata'}{'dnum'});
    }
    # if this is not a dummy node then make the branch closeable and close it
    if ($model->{'nodes'}{$i}{'nodetype'} != NODE_DUMMY) {
      $tree->setmode(".nodes.$i.subhead", "close");
      $tree->close(".nodes.$i.subhead");
    }
    $tree->setmode(".nodes.$i.header", "close");
    $tree->close(".nodes.$i.header");
    $tree->setmode(".nodes.$i", "close");
    $tree->close(".nodes.$i");
  } # geometry node loop
        
  $tree->setmode(".nodes", "close");
  $tree->close(".nodes");
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
  print ("\n\n");
}
