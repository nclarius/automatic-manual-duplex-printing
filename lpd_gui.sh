#!/bin/bash

###############
# Automatic manual duplex printing (KDE graphical interface)
# (C) 2021 Natalie Clarius <natalie_clarius@yahoo.de>
# GNU General Public License v3.0
###############


###############
# configuration
###############

printer=Epson_Stylus_SX440
order=1


###############
# initialization
###############

# initial variables
if [ $# -eq 1 ]  # check if argument is provided
then
    filename=$1  # file name = arg
else
    filename=$(kdialog --title "Duplex Print" --getopenfilename)  # select file from dialog
fi
num_pages=$(pdfinfo $filename | grep Pages | awk '{print $2}')  # number of pages in document
start=$(kdialog --title "Duplex Print" --inputbox "Start of page range" 1)  # start of page range (default: 1)
end=$(kdialog --title "Duplex Print" --inputbox "End of page range" $num_pages)  # end of page range (default: num_pages)
multi=$(kdialog --title "Duplex Print" --inputbox "Pages per sheet" 1)  # pages per sheet (default: 1)
kdialog --title "Duplex Print" --yesno "Print in color?"  # color vs gray scale
if [[ $? -eq 0 ]]; then color=true; else color=false; fi

first=$(( ($start+$multi-1)/$multi ))  # first multipage to print
last=$(( ($end+$multi-1)/$multi ))  # last multipage to print
start_=$(( (($first-1)*$multi)+1  ))  # start of printed page range
end_=$(( $last*$multi ))  # end of printed page range
num_sheets=$(( $last-$first+1 ))

# sort into front, back and remainder pages
front_=()
back_=()

i=1
for ((p=first; p<=last; p++))
do
  if ((i % 2))
  then
      front_+=($p)  # odd  multipages to front
  else
      back_+=($p)  # even multipages to back
  fi
  i=$((i+1))
done

if [[ ${#back_[@]} -eq 0 ]]  # only single front page
then
  backapges=false
  remainder=false
else
  backpages=true

  if (( ${#front_[@]} > ${#back_[@]} ))  # more front than back pages
  then
      remainder=true
  fi
fi

# convert page range to comma-separated string
function join_by { local IFS="$1"; shift; echo "$*"; }
front=$(join_by , "${front_[@]}")
back=$(join_by , "${back_[@]}")

# notify user of initialization
kdialog --title "Duplex Print" --yesno "File: $filename\nPages per sheet: $multi\nPage range: $start_-$end_\nNumber of pages: $num_sheets\nColor: $color\nContinue?"
if [[ $? -ne 0 ]]
then
    kdialog --title "Duplex Print" --passivepopup "Cancelled"
    exit 3
fi
kdialog --title "Duplex Print" --passivepopup "Printing ..."

###############
# printing
###############

# execute print job
send_print_job () {   # send print job and return job id
    # $1: file name, $2: page range, $3: multi, $4: reverse, $5: color
    printrequest="lp -d $printer" # basic print request
    if [[ $# -eq 0 ]]
    then
        echo $(lp -d $printer <<< "" | sed -e "s/request id is \(.*\) (0 file(s))/\1/") # last empty backpage
    else
        printrequest="lp -d $printer" # basic print request
        printrequest+=" -o page-ranges=$2" # page range
        if [[ "$3" = true ]]; then printrequest+=" -o number-up=$3"; fi  # multi-page print
        if [[ "$4" = true ]]; then printrequest+=" -o outputorder=reverse"; fi # reverse order
        if [[ "$5" = false ]]; then printrequest+=" -o Color=Grayscale"; fi # color
        printrequest+=" $1 " # file name
        echo $($printrequest | sed -e "s/request id is \(.*\) (1 file(s))/\1/")
    fi
}

# monitor print job status
monitor_print_job () {
    # $1: job id
    completed=false
    until $completed
    do
        sleep 5  # check only every 5 seconds
        completed_jobs=$(lpstat -W completed $printer | awk "{print \$1}")  # get completed print jobs
        if [[ "$completed_jobs" == *"$1"* ]]; then completed=true; fi                 # check if current job is among completed; if yes, proceed
    done
}

# print
if [[ "$order" == 1 ]] # order variant 1: first front pages, then back pages, then last empty back page
then

    # print front pages
    reverse=false
    front_job=$(send_print_job $filename $front $multi $reverse $color)
    monitor_print_job $front_job

    if [[ "$backpages" = true ]]
    then
        # prompt user to turn paper
        kdialog --title "Duplex Print" --msgbox "Please turn the paper, then click OK."

        # print back pages
        reverse=false
        back_job=$(send_print_job $filename $back $multi $reverse $color)
        monitor_print_job $back_job

        # print last empty back page
        if [[ "$remainder" = true ]]
        then
            remainder_job=$(send_print_job)
            monitor_print_job $remainder_job
        fi
    fi

elif [[ "$order" == 2 ]] # order variant 2: first reversed back pages, then front pages
then
    if [[ "$backpages" = true ]]
    then

        # print back pages
        reverse=true
        back_job=$(send_print_job $filename $back $multi $reverse $color)
        monitor_print_job $back_job

        # prompt user to turn paper
        kdialog --title "Duplex Print" --msgbox "Please turn the paper, then click OK."
    fi

    # print front pages
    reverse=false
    front_job=$(send_print_job $filename $front $multi $reverse $color)
    monitor_print_job $front_job
fi

# notify user of completion
kdialog --title "Duplex Print" --passivepopup "Done"
