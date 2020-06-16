-----------------------------------------------------------------
--<< mdlops v1.0.1 by Chuck Chargin Jr. (cchargin@comcast.net) >>--
-----------------------------------------------------------------

-------------------------
--<< Version history >>--
-------------------------

 July 1 2004: First public release of mdlops.pl version 0.1
                
 July 17 2004: Added support for vertex normals (thanks JRC24)

 August 4 2004: Fixed division by zero bug in vertex normals (thanks Svosh)

 October 18, 2004: 	Version 0.3
                   -Now ignores overlapping vertices 
                   -fixed a bug that caused some controllers 
                     to be ignored (thanks T7nowhere and Svosh)
                   -updated docs on how texture maps work in
                     kotor (thanks T7nowhere and Svosh)
                   -new tutorial written by bneezy
                   -Svosh updated the quick model tutorial
 November 18, 2004: 	Version 0.4
                   added replacer function (idea originally suggested to me by tk102)
                   gui does not get built when using command line (thanks Fred Tetra)
                   added ability to rename textures in binary models (thanks darkkender)
                   cool new icon created by Svosh.  Thanks Svosh!

 March 8, 2005: 	Version 0.5
                   figured out that some meshes have 2 textures (thanks Fred Tetra)
                   added fix for meshes that have 0 verticies (thanks Fred Tetra)
                   added support for Kotor 2.  The model is bigger by only 8 bytes per mesh!
                   the program will auto-detect if a binary model is from kotor 1 or kotor 2

 March 9, 2006: 	Version 0.6alpha4
                   Added aabb support (thanks Fred Tetra)
                   Vastly improved ascii import speed (optimized the adjacent face routine)
                   Added partial support for aurora lights
                   ANIMATIONS! MUCH MUCH thanks to JdNoa for her cracking of the compressed quaternion format
                   and for writing the animation delta code!

 May 21, 2007:		version 0.6.1alpha1 (changes by JdNoa)
                   Added support for compiling animations.  Code mostly ported from Torlack's NWN compiler.
                   Added controllers for lights and emitters, but not tested yet.

 January 13, 2016:	Version 0.7alpha
                   Reworked calculations of face normals
                   Reworked calculations of vertex normals

 Summer, 2017:         Version 1.0.0
                   Reworked calculations of face, vertex normals, plane distances, adjacent faces
                   Added tangent space calculations
                   Added emitter and finished light node support
                   Added walkmesh support (DWK/PWK/WOK)
                   Added lightsaber mesh support and conversion
                   Added bezier controller support and fixed existing controller list
                   Added normalization of vertex data into MDX form
                   Added detection of real smoothgroups
                   Added reference node support
                   Added super model node number construction
                   Fixed replacer for many cases
                   Many more small fixes and features

 January, 2017:        Version 1.0.1
                   Fixed compression and decompression of quaternions
                   Fixed axis-angle to quaternion conversion
                   Fixed walkmesh use point encoding, off-by-one
                   Fixed ascii walkmesh node naming
                   Fixed walkmesh compatibility with mdledit/kmax

-----------------
--<< License >>--
-----------------
 This script is released under the GPL, see the included
 GPL.txt.

----------------
--<< Thanks >>--
----------------
 MUCH MUCH MUCH thanks to Torlack for his NWN MDL info!
 Without his info this script could not exist!

 Thanks to my testers:
   T7nowhere
   Svosh
   Seprithro
   ChAiNz.2da

 Thanks to all at Holowan Laboratories for your input
 and support

 file browser dialog added by tk102

 AABB, animations, lights and emitters, and speed-up by JDNoa

 Calculations of vertex and face normals by VP and Fair Strides

 1.0 version by ndix UR, thanks to bead-v for inspiring many of the added
 features, figuring out a number of critical format algorithms, and sharing
 the journey

-----------------------
--<< What is this? >>--
-----------------------
 
 This is a Perl script for converting
 Star Wars Knights of the Old Republic (kotor 1 for short)
 AND Star Wars Knights of the Old Republic, The Sith Lords (kotor 2 for short)
 binary models to ascii and back again.

 Binary models are converted to an ascii format compatible
 with NeverWinter Nights.
 
 It can also do some other operations on models,
 like renaming textures and replacing meshes.

------------------
--<< Features >>--
------------------
 -Automatic detection of binary model version
 -Automatic detection of model type
 -node types supported:
   -trimesh
   -danglymesh
   -lightsaber
   -skin
   -emitter
   -light
   -reference
   -dummy
 -model properties supported:
   -diffuse
   -ambient
   -shadow
   -render
   -alpha
   -self illumination
   -many, many more
 -supports compile/decompile pwk/dwk/wok walkmesh files
  along with their associated models
 -when reading in a binary model a text file is created 
  that lists all the textures the model uses.
 -replacer function lets you replace 1 tri-mesh in a binary
  model with another tri-mesh from an ascii model
 -renamer function lets you rename textures in a binary
  model
 
 read the tutorials "KotOR_Tutorial.txt" and "Quick_tutorial.txt"
 for an explanation of how to get your models into kotor

----------------------------
--<< Command line usage >>--
----------------------------
 command line usage of the compiled perl script:
 View all command line options:
 mdlops.exe --help
 mdlops.exe [options] [-k1|-k2] c:\directory\model.mdl
 OR
 mdlops.exe [options] [-k1|-k2] c:\directory\*.mdl

 command line usage of perl scripts:
 NOTE: you must first copy the MDLOpsM.pm file into your \perl\lib or
 \perl\site\lib directory
 View all command line options by running:
 perl mdlops.pl --help

 perl mdlops.pl [-a] [-s] [-k1|-k2] c:\directory\model.mdl
 OR
 perl mdlops.pl [-a] [-s] [-k1|-k2] c:\directory\*.mdl

 For the command line the following switches can be used:
 -a will skip extracting animations
 -s will convert skin to trimesh
 -k1 will output a binary model in kotor 1 format
 -k2 will output a binary model in kotor 2 format
and many more...

Notes:
 1: The script automatically detects the version
    of the input binary model.

 2: mdlops by default DOES extract animations and DOES NOT
    convert skin to trimesh.

 3: The script automatically detects the type
    of model.

 4: For binary models you must have the .MDL and .MDX
    in the same directory

 5: For importing models that have supermodels, the super model or
    the original model must be in the same directory as
    model being imported. Super model is better.

 6: Running uncompiled version requires perl 5.12+ and JSON package from CPAN.

-------------------
--<< GUI usage >>--
-------------------
Import/export usage:
 1) In a command prompt: perl mdlops.pl OR double click mdlops.exe
 2) click 'select file'
 3) browse to directory that has your .MDL file.
    Select the .MDL and click 'open'
 4) To quickly convert the model click 'Read and write model'
    NOTE: The script will automatically detect the model type.
 5) If you started with a binary file (ex. model.mdl) then the
    resulting ascii model will be model-ascii.mdl
 6) If you started with an ascii file (ex. model.mdl) then the
    resulting binary model will be model-bin.mdl
 7) The 'view data' button will let you view the raw data for
    a model loaded from binary source.  This does not work
    with models loaded from ascii source.

 NOTE: reading in ascii files that have models with lots of
       polygons will be slow!  You can watch the progress
       in the command prompt window.

Renamer usage:
 1) start mdlops
 2) click 'select file'
 3) browse to directory that has your .MDL file.
    Select the .MDL and click 'open'
 4) click on 'read model'
 5) click on 'renamer'
 6) type in a new texture name in the "New name" box
 7) click on the mesh that needs its texture renamed
 8) click "change name"
 9) when you are done changing names, click "write model"
    The model will be written to the same directory as
    the original with the name model-rbin.mdl and
    model-rbin.mdx

Replacer usage:
  see the included 'replacer_tutorial.txt'

-------------------------------------------
--<< Important texture map information >>--
-------------------------------------------

For those of you familiar with texturing the bad news is the 
way the polygon vertices and texture vertices are stored
it is not possible for a single polygon vertex to have
multiple texture vertices.

For example, if you had a simple cube where all the polygon
vertices were welded you would have 8 polygon vertices.
So when you texture your cube you would only have 8 texture
map vertices to work with.  

If you wanted your UV map to look like 6 separate squares
you would have to split the polygon vertices, but weld the
polygon vertices for each side.  This would give you 24
polygon vertices and 24 texture vertices.

If you wanted to have separate polygons you would have
36 polygon vertices and 36 texture vertices.

If you use the 'validate vertex data' option, mdlops will do all
the work to make your model come out correctly, as far as this is concerned.

--------------------------------------
--<< Other software you will need >>--
--------------------------------------
To get models out of kotor files:
Kotor Tool
http://kotortool.home.comcast.net/index.html
OR
Xoreos Tools
https://github.com/xoreos/xoreos-tools

To edit the models
GMax (it is free, windows-only)
http://www.discreet.com/products/gmax/
OR
Blender (it is free, cross-platform)
https://www.blender.org

To get models in and out of Gmax, Max, or Blender
KOTORMax (to get models in and out of Gmax or Max)
Kotorblender (to get models in and out of Blender)
