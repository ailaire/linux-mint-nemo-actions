#!/bin/sh
#
########################
# scan-to-sandwich-pdf #
########################
#
###############
# Description #
###############
# This script optimizes scans and adds a text layer to the document 
# so you end up with a searchable and indexable pdf multipage document 
# (so called sandwich-pdf).
# The output file will be black/white for better text recognition.
# The original file gets saved in the archive directory defined hereunder 
# (default: /home/$USER/Scan-Archive).
#
# Input:  pdf or tif singlepage or multipage document.
# Output: multipage pdf document (searchable, indexable, black/white).
#
################
# Dependencies #
################
# Make sure you have installed the following packages on your system: 
#    - zenity
#    - ghostscript 
#    - scantailor 
#    - tesseract-ocr (at least version 3.0.0)
#    - tesseract-ocr-deu tesseract-ocr-fra (and every other language-file you need)
#    - exactimage 
#    - pdftk
#
# You can do this using the following commands:
#   sudo apt-get update
#   sudo apt-get install zenity ghostscript scantailor tesseract-ocr tesseract-ocr-deu tesseract-ocr-fra exactimage pdftk
#
########################################
# User-Variables (change, if you like) #
########################################
# Workdirectory for temporary files
tmpdir="/tmp/scan-hocr" ;
# The output's name will be the input document's name plus a suffix. 
# Whithout suffix the original file will be overwritten.
suffix="" ;
# Archive directory (Where the original file will be saved)
archivedir="/home/$USER/Scan-Archive" ;
#
#########################################
# Script (no changes needed, hopefully) #
#########################################
#
# further variables
file="$1" ;
basename=`basename "$file"` ;
fbname="${basename%.*}" ;
basenamenospaces=`echo "$basename" | sed 's| |_|g'` ;
fbnamenospaces="${basenamenospaces%.*}" ;
dirname=`dirname "$file"` ;
workdir="$tmpdir/$fbnamenospaces" ;
archivename="`date +"%F_%H-%M-%S"`_$basenamenospaces" ;
#
# Ask for the primary language of the document
seltesslang=$(zenity --list \
                     --hide-header \
                     --text="Wähle die primäre Sprache des Dokuments" \
                     --title "Scanaufbereitung «$basename»" \
                     --width=400 --height=150 \
                     --radiolist --column "" --column "" TRUE "deutsch" FALSE "französisch" FALSE "englisch" ) ;
#
case "$seltesslang" in 
"deutsch")tesslang="deu";;
"französisch")tesslang="fra";;
"englisch")tesslang="eng";;
esac 
#
# Go into directory
(
echo "0" ;
echo "# Originaldatei wird in "$archivedir" gesichert" ;
cd "$dirname" ;
#
# create direcotories
mkdir -p $tmpdir $workdir $archivedir ;
mkdir -p $workdir/c2p-tif $workdir/c2p-tif-out ;
#
# backup the original file
cp "$file" "$archivedir/$archivename" ;
#
# Split up the multipage document to single pages in tif-format
echo "13" ;
echo "# Das Dokument wird in Einzelseiten zerlegt" ;
gs -q -dNOPAUSE -r300 -sDEVICE=tiffgray -sOutputFile="$workdir/c2p-tif/$fbname-%03d.tif" "$basename" -c quit ;
#
# call scantailor to split double pages, remove borders, black and white, etc.
# If scantailor removes too much Border add "--content-detection=cautious" 
# behind scantailor-cli (whith spaces and whitout the "")
echo '25' ;
echo "# Scantailor bearbeitet die Seiten" ;
for i in $workdir/c2p-tif/*.tif ;
do scantailor-cli --margins=5 --alignment=center --dpi=300 --output-dpi=300 "$i" "$workdir/c2p-tif-out" ;
done ;
#
# Optical character recognition by tesseract-ocr
echo "38" ;
echo "# Texterkennung wird ausgeführt" ;
for i in $workdir/c2p-tif-out/*.tif ; 
do tesseract "$i" "$i" -l $tesslang -psm 1 hocr ;
done ;
#
# Generate sandwich-pdf (pdf-document with text layer and picture) single pages.
echo "50" ;
echo "# Textschicht und Bild werden zusammengefügt" ;
for i in $workdir/c2p-tif-out/*.tif ;
do hocr2pdf -i "$i" -s -o "$i.pdf" < "$i.html" ;
done;
#
# Merge the single page pdf documents to a multipage pdf document
echo "63" ;
echo "# Die einzelnen Seiten werden zu einem Dokument zusammengesetzt" ;
pdftk $workdir/c2p-tif-out/*.pdf cat output "$workdir/$fbname-big.pdf"
#
# Delete the original file
rm "$basename" ;
#
# Optimize the document's size
echo "75" ;
gs -sDEVICE=pdfwrite -sPAPERSIZE=a4 -dCompatibilityLevel=1.4 -dPDFSETTINGS=/default -dNOPAUSE -dQUIET -dBATCH -sOutputFile="$fbname$suffix.pdf" "$workdir/$fbname-big.pdf" ;
#
# Clean up
echo "88" ;
rm $workdir/c2p-tif/*.tif $workdir/c2p-tif-out/*.tif $workdir/c2p-tif-out/*.html $workdir/c2p-tif-out/*.pdf $workdir/c2p-tif-out/cache/thumbs/*.png $workdir/c2p-tif-out/cache/speckles/*.tif $workdir/*.pdf ;
rmdir $workdir/c2p-tif $workdir/c2p-tif-out/cache/thumbs $workdir/c2p-tif-out/cache/speckles $workdir/c2p-tif-out/cache $workdir/c2p-tif-out $workdir ;
echo "100" ;
echo "# Aufbereitung erfolgreich abgeschlossen." ;
) | zenity --progress \
     --title "Scanaufbereitung «$basename»" \
     --text "«$basename» wird bearbeitet" \
     --pulsate --width=400 --auto-close --auto-kill ;
zenity --info  \
  --text="«`echo "$basename"`» wurde erfolgreich aufbereitet. 
Eine Kopie des Originals wurde im Archiv (`echo "$archivedir"`) abgelegt." \
  --title="Scanaufbereitung abgeschlossen" \
  --no-wrap --width=400 ;