#! /bin/bash

#### Variables ####
# TempFiles
scanerinfosFile="scanerinfos.txt"
devicesFile="devices.txt"
dockersFile="dockers.txt"
indexFile="index.txt"
colorFile="color.txt"
logFile="scans.log"

#Scaner Info
usbScanerName="5590"
scanimageDeviceName="hp5590:libusb"

#### Functions ####

# Call the scanservjs with a REST POST Request
# Template is filled with global variables
scan() {
#echo \
curl -X 'POST' \
  'http://scan/api/v1/scan' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "params": {
    "deviceId": "'$scanimageDeviceName':'$bus':'$device'",
    "top": 0,
    "left": '$left',
    "width": 210,
    "height": 297,
    "pageWidth": 210,
    "pageHeight": 297,
    "resolution": '$resolution',
    "mode": "'$mode'",
    "source": "'$source'",
    "adfMode": "'$adfMode'",
    "brightness": 0,
    "contrast": 0,
    "dynamicLineart": false,
    "ald": "yes"
  },
  "filters": [
    "filter.auto-level",
    "filter.threshold"
  ],
  "pipeline": "PDF (JPG | @:pipeline.high-quality)",
  "batch": "'$batchMode'",
  "index": '$index'
}'
#>scanCommand.txt
}

# Find the $searchText in the $file, create tokens separated by space 
# Return $token without first and last letter (remove square brackets)
findInFile() { 
    searchText=$1
    index=$2  
    file=$3

    foundLine=`grep $searchText $file`
    tokens=(${foundLine// / })
    token=${tokens[$index]:1:-1}
    echo $token
}

#Find the text $1 in the file $scanerinfosFile. Return token at index $2
findInScaninfo() {
    echo $(findInFile $1 $2 $scanerinfosFile)
}

#### Main ####
dt=`date '+%Y-%m-%d %H:%M:%S'`
echo . 
echo $dt start scans.sh

# list all USB Devices
lsusb>$devicesFile
# Find line with our USB scanner "5590"
usbScaner=`grep $usbScanerName $devicesFile`
#usbScaner="Bus 001 Device 005: ID 03f0:1705 HP, Inc ScanJet 5590"
# tokenisze $usbScaner
usbScanerArr=(${usbScaner// / })
bus=${usbScanerArr[1]}
device=${usbScanerArr[3]::-1}
echo $dt Scanner hp$usbScanerName on bus:$bus device:$device

# Find docker containerId of "sbs20/scanservjs"
docker ps>$dockersFile
container=`grep scanservjs $dockersFile`
#container="1ab77b38b151 sbs20/scanservjs:latest "/entrypoint.sh" 2 months ago Up 9 days 0.0.0.0:80->8080/tcp, [::]:80->8080/tcp scanserverjs"
containerTokens=(${container// / })
containerId=${containerTokens[0]}
echo $dt scanservjs docker containerId:$containerId

#define/initialize global variables for the scan function
resolution=300
source="Flatbed"
adfMode="Simplex"
batchMode="none"
left="0"

#initialize $indexFile
if [ ! -f $indexFile ]; then
    echo "0">$indexFile
fi
index=`cat $indexFile`

# inizialize $colorFile
if [ ! -f $colorFile ]; then
    echo Color>$colorFile
fi
mode=`cat $colorFile`

while true
do
    # Get all options for specific scaner
    # echo docker exec $containerId sh -c "scanimage --format=pnm -p -A -d $scanimageDeviceName:$bus:$device"
    docker exec $containerId sh -c "scanimage --format=pnm -p -A -d $scanimageDeviceName:$bus:$device">$scanerinfosFile

    # get pressed button
    button=$(findInScaninfo "button-pressed" 2)
    #echo $button
    counter=$(findInScaninfo "counter-value" 6)

    # evaluate the pressed button and set global variables for this scan function
    dt=`date '+%Y-%m-%d %H:%M:%S'`

    case "$button" in
        "none")
            #echo none
        ;;

        "power")
            echo $dt power
        ;;

        "scan")
            echo $dt scan flatbed one page
            source="Flatbed"
            adfMode="Simplex"
            index=1
            echo "0">$indexFile
            scan
        ;;
        
        "collect")
            echo $dt scan adf
            source="ADF"
            adfMode="Simplex"
            batchMode="auto"
            left="2.5" #ADF is centered, left start of page has to be moved by 2.5
            index=1
            scan
        ;;
        
        "file")
            echo $dt scan adf duplex
            source="ADF Duplex"
            adfMode="Duplex"
            batchMode="auto"
            left="2.5"
            scan
        ;;
        
        "email")
            source="Flatbed"
            batchMode="manual"
            index=`cat $indexFile`
            ((index++))
            echo "$index">$indexFile
            echo $dt scan manual batch flatbed $index
            scan
        ;;
        
        "copy")
            echo $dt scan manual batch end. $index pages scaned
            source="Flatbed"
            batchMode="manual"
            index=-1
            echo "0">$indexFile
            scan
        ;;

        "up")
            echo $dt up: $counter
        ;;

        "down")
            echo $dt down: $counter
        ;;

        "mode")
            scanMode=$(findInScaninfo "mode" 4)
            if [ $mode = "Color" ]; then mode="Gray"; else mode="Color";fi
            echo $dt mode $scanmode to $mode
        ;;

        "cancel")
            echo $dt cancel
            index=0
            echo "0">$indexFile
        ;;

        *)
            #echo $dt nothing to do
        ;;
    esac
    sleep 2
done
