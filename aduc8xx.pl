#!/usr/bin/perl
# ******************************************************************************
#   PRECMA S.r.l.  -  Electronic Engineering  -  http://www.precma.com
#       Progettazione Elettronica Controlli di Macchine Automatiche
#
# ADuC842 Downloader
# In System Analog Devices AD842 (and others) microcontrollers programmer
# Using perl module Device::SerialPort (http://sendpage.org/device-serialport/)
#
# Developed under Linux (SuSE 9.2 - 10.2 - 10.3); works with Windows, too (using
# Win32::SerialPort module)
#
# -----------------------------------------------------------------------------
# Version 1.1 (090707)
# Support for some USB/RS232 converters (FTDI)
# -----------------------------------------------------------------------------
# Version 1.0 (080711)
# Thanks to Peter Gaus for bugfix in data ROM programming and +/- 1 problem 
# with variable $TOP_ADDR
# -----------------------------------------------------------------------------
# Version 0.9 (070703)
# Reduced dots output to speed up in windows mode
# -----------------------------------------------------------------------------
# Version 0.8 (070415)
# Enhanced programming speed: 32K in ~25sec instead of ~42sec
# -----------------------------------------------------------------------------
# Version 0.7 (060418)
# "Enable Custom Bootloader" Command
# -----------------------------------------------------------------------------
# Version 0.6 (051216)
# Detect option
# -----------------------------------------------------------------------------
# Version 0.5 (051213)
# Quickmode; goto Fine instead of exit;
# -----------------------------------------------------------------------------
# Version 0.4 (051213)
# Always erase before programming
# -----------------------------------------------------------------------------
# Version 0.3 (051108)
# Speed up initial checks
# -----------------------------------------------------------------------------
# Version 0.2 (051028)
# Try to support OSX
# -----------------------------------------------------------------------------
# Version 0.1 (051009)
# First release
# -----------------------------------------------------------------------------
# Fausto Marzoli - faumarz@8052.it
# Copyright (C)2005-2008 PRECMA S.r.l. - http://www.precma.com/
# ******************************************************************************
# TODO: Security modes



use strict;
use vars qw( $OS_win $ob );
use Getopt::Long;


#_______________________________________________________________________OS Check
BEGIN
{
    $OS_win = ($^O eq "MSWin32") ? 1 : 0;
    if ($OS_win)
    {
        eval "use Win32::SerialPort 0.11";
        die "$@\n" if ($@);
    }
    else
    {
        eval "use Device::SerialPort";
        die "$@\n" if ($@);
    }
} # End BEGIN


#______________________________________________________________________Variables
my $Prog = "ADuC8xx Programmer";
my $Ver = "Version 1.1 (090707)";
my $Copyright = "Copyright 2005-2009 PRECMA Srl";
my $Use = "Usage: aduc8xx [--opt1 [arg1[,arg2]] ... --optn [arg1[,arg2]]]";

my $CfgFile = "$ENV{HOME}/.aduc8xx.cfg";

my $optHelp;
my $optEflash;
my $optEchip;
my $optPort;
my $optProgram;
my $optData;
my $optSecurity;
my $optRun;
my $optQuickmode;
my $optDetect;
my $optBootload;

my $Res;
my @strRomImage;
my $RecLen = 0x10;              # 16 bytes programming record
my $DataPageLen = 0x04;         #  4 bytes data record

my $ACK = 0x06;
my $NACK = 0x07;
my $TOP_ADDR;


#________________________________________________________________Welcome message
print "$Prog $Ver - $Copyright\n";


#_________________________________________________________________Argument Check
&GetOptions  (
#             "o"=>\$oflag,
#             "verbose!"=>\$verboseornoverbose,
#             "string=s"=>\$stringmandatory,
#             "optional:s",\$optionalstring,
#             "int=i"=> \$mandatoryinteger,
#             "optint:i"=> \$optionalinteger,
#             "float=f"=> \$mandatoryfloat,
#             "optfloat:f"=> \$optionalfloat
            "help"=>\$optHelp,
            "detect:i"=>\$optDetect,
            "eflash"=>\$optEflash,
            "echip"=>\$optEchip,
            "quickmode=s"=>\$optQuickmode,
            "program=s"=>\$optProgram,
            "data=s"=>\$optData,
            "security=s"=>\$optSecurity,
            "bootload=s"=>\$optBootload,
            "run=s"=>\$optRun,
            "port=s"=>\$optPort
            );


if ($optHelp)
{
    print "$Use
--help             Show options
--detect [baud]    Try to initiate the communication at the given baudrate
  (default 9600baud, setting depends on your system clock - see aduc8xx.txt)
--eflash           Erase Flash Memory
--echip            Erase Flash & Data Memory
--quickmode s,b    Change the programming baud rate: s=T3CON:T3FD b=baudrate
  (available for the Timer 3 enabled derivates only - see aduc8xx.txt)
--program hexfile  Program in the flash ROM the given hexfile
--data hexfile     Program in the data ROM the given hexfile
--security         TODO
--bootload [E/D]   Enable (E) or disable (D) the custom bootloader startaddress
--run hexaddr      Execute user code from addr (hex)
--port p           Define serial port to use (i.e. /dev/ttyS0)
Bootloader is initiated by the --detect option and stopped by the --run option
Examples:
aduc8xx.pl --detect --echip --program dummy.hex --run 0
  Erase chip, program it \@9600baud and start the code
aduc8xx.pl --detect --program dummy.hex --quickmode 8309,57600
  Erase chip, program it \@57600baud (quickmode for ADuC842\@32KHz)
";
goto Fine;
}


#_______________________________________________________________Serial Port Open
if ($optPort ne "")
{
    if ($OS_win) {
        $ob = Win32::SerialPort->new ("$optPort");
    }
    else {
        $ob = Device::SerialPort->new ("$optPort");
    }
    die "Can't open serial port $optPort: $^E\n" unless ($ob);
#    $ob->save("$CfgFile");
}
elsif (-e"$CfgFile")
{
    if ($OS_win) {
        $ob = Win32::SerialPort->start ("$CfgFile");
    }
    else {
        $ob = Device::SerialPort->start ("$CfgFile");
    }
    die "Can't open serial port from $CfgFile: $^E\n" unless ($ob);
}
else
{
    print "No serial port defined: use --port option\n";
    goto Fine;
}

# $ob->baudrate(9600)     || die "Fail setting serial port baud rate";
# $ob->parity("none")     || die "Fail setting serial port parity";
# $ob->databits(8)        || die "Fail setting serial port databits";
# $ob->stopbits(1)        || die "Fail setting serial port stopbits";
# $ob->handshake("none")  || die "Fail setting serial port handshake";
# $ob->write_settings     || die "No serial port settings";
# $ob->save("$CfgFile");


# When you start the device ISP mode, it sends 25 bytes: this read clears the buffer
$ob->read_const_time(50);
$Res = $ob->read(255);



#___________________________________________________________Check for the device
if (($optDetect ne "") && ($optDetect == 0))
{
    $optDetect = 9600;
}

if ($optDetect ne "")
{
$ob->baudrate($optDetect)   || die "Fail setting serial port baud rate";
$ob->parity("none")         || die "Fail setting serial port parity";
$ob->databits(8)            || die "Fail setting serial port databits";
$ob->stopbits(1)            || die "Fail setting serial port stopbits";
$ob->handshake("none")      || die "Fail setting serial port handshake";
$ob->write_settings         || die "No serial port settings";
#$ob->save("$CfgFile");

    print "Detecting device ... ";
    system;
    $ob->write("!Z");
    $ob->write(chr(0x00));
    $ob->write(chr(0xA6));
    $Res = &strWaitResponse();
    if ($Res eq "")
    {
        print "Error\nNo device detected: please check connection and force the device in ISP mode\n";
        goto Fine;
    }
    else
    {
        print "done. Connected device: $Res\n";
        system;
        # Gets the other 10 bytes of the start string (clears the buffer)
        $ob->read_const_time(50);
        $Res = $ob->read(255);
    }
}
else
{
    $ob->baudrate(9600)     || die "Fail setting serial port baud rate";
    $ob->parity("none")     || die "Fail setting serial port parity";
    $ob->databits(8)        || die "Fail setting serial port databits";
    $ob->stopbits(1)        || die "Fail setting serial port stopbits";
    $ob->handshake("none")  || die "Fail setting serial port handshake";
    $ob->write_settings     || die "No serial port settings";
#    $ob->save("$CfgFile");
}
system;


# Options that include others
if  (
($optProgram ne "") && ($optEflash eq "") && ($optEchip eq "") && ($optDetect ne "")
    )
{
    $optEflash = 1;
}


#_______________________________________________________________Erase Flash Only
if ($optEflash)
{
    print "Erasing Flash ROM ... ";
    system;
    $ob->write(chr(0x07));
    $ob->write(chr(0x0E));
    $ob->write(chr(0x01));
    $ob->write("C");
    $ob->write(chr(0xBC));
    $Res = &strWaitACK();

    if ($Res eq $ACK)
    {
        print "done\n";
    }
    elsif ($Res eq $NACK)
    {
        print "error - aborting\n";
        goto Fine;
    }
    else
    {
        print "unknown response - aborting\n";
        goto Fine;
    }
}
system;


#_____________________________________________________________Erase Flash & Data
if ($optEchip)
{
    print "Erasing Flash & Data ROM ... ";
    system;
    $ob->write(chr(0x07));
    $ob->write(chr(0x0E));
    $ob->write(chr(0x01));
    $ob->write("A");
    $ob->write(chr(0xBE));
    $Res = &strWaitACK();

    if ($Res eq $ACK)
    {
        print "done\n";
    }
    elsif ($Res eq $NACK)
    {
        print "error - aborting\n";
        goto Fine;
    }
    else
    {
        print "unknown response - aborting\n";
        goto Fine;
    }
}
system;


if ($optQuickmode ne "")
{
my $riga;
my $g;
my @SplitArg;
my $SFR_setting;
my $BaudRate;

    print "Setting Quickmode baud rate ... ";
    system;

    @SplitArg = split(",", $optQuickmode);
    $SFR_setting = $SplitArg[0];
    $BaudRate = $SplitArg[1];

    # Set the baud rate to 57600
    #       len  Cmd  T3CON+T3FD
    $riga = "03"."42".$SFR_setting;              # "42" is the hex ascii code for 'B'
    $riga = &strAddCheckSum($riga);
    $ob->write(chr(0x07));
    $ob->write(chr(0x0E));
    for ($g = 0; $g < length($riga); $g += 2)
    {
        $ob->write(chr(hex(substr($riga, $g, 2))));
    }

    $Res = &strWaitACK();
    if ($Res eq $ACK)
    {
        $ob->baudrate($BaudRate) || die "Fail setting serial port baud rate";
        $ob->write_settings      || die "No serial port settings";
        print "done\n";
    }
    elsif ($Res eq $NACK)
    {
        print "FAILED\n";
        goto Fine;
    }

}
system;


#__________________________________________________________________Program Flash
if ($optProgram ne "")
{
    my $i;
    my $g;
    my $isTobeProg;
    my $riga;
    my $len;
    my $offset;
    my $DonePages = 0;

    my $TOP_ADDR = 0xF800;          # 62Kb


    # Fill the ROM with "00"
    for ($i = 0 ; $i < $TOP_ADDR; $i++)
    {
        $strRomImage[$i] = "00";
    }

    # Open firmware file and read it
    if (-e"$optProgram")
    {
        open SOURCE_FILE, "$optProgram" or die;
        while ($riga = <SOURCE_FILE>)
        {
            $riga = Trim($riga);
            
            # If EOF record end
            if ($riga eq ":00000001FF")
            {
                last;
            }
            
            $len = hex(substr($riga, 1, 2));
            $offset = hex(substr($riga, 3, 4));
            # If it is a data record, read it
            if ( (hex(substr($riga, 7, 2))) == 0 )
            {
                for ($i = 0; $i < $len; $i++)
                {
                    if (($offset + $i) < $TOP_ADDR)
                    {
                        $strRomImage[$offset + $i] = substr($riga, (9 + ($i * 2)), 2);
                    }
                    else
                    {
                        print "The HEX file exceeds the device flash ROM dimension: programming interrupted.\n";
                        print "Maybe the program is too big or you are trying to write locations out of memory\n";
                        close SOURCE_FILE;
                        goto Fine;
                    }
                }
            }
        }
        close SOURCE_FILE;
    }
    else
    {
        print "The $optProgram file does not exist\n";
        goto Fine;
    }

    # Program micro
    print "Programming device flash ROM ...";
    system;
    for ($i = 0; $i < $TOP_ADDR; $i += $RecLen)
    {
        $offset = strDecToHex24($i);
        $len = strDecToHex8($RecLen+4);         # includes command and 24bit address
        $riga = $len."57".$offset;              # "57" is the hex ascii code for 'W'
        
        $isTobeProg = 0;
        for ($g = 0; $g < $RecLen; $g++)
        {
            $riga = $riga.$strRomImage[$i + $g];
            if ($strRomImage[$i + $g] ne "00")
            {
                $isTobeProg = 1;
            }
        }
        
        # If it is a page to be programmed, send it
        if ($isTobeProg)
        {
            # The "system" calls are needed for some USB/RS232 converters (i.e. FTDI)
            $riga = &strAddCheckSum($riga);
            $ob->write(chr(0x07));
            system;
            $ob->write(chr(0x0E));
            for ($g = 0; $g < length($riga); $g += 2)
            {
                system;
                $ob->write(chr(hex(substr($riga, $g, 2))));
            }
            system;
            
            $Res = &strWaitACK();
            if ($Res eq $ACK)
            {
                $DonePages += 1;
            }
            elsif ($Res eq $NACK)
            {
                print " NACK\nProgramming Chip: failed\n";
                goto Fine;
            }
            else
            {
                print " X\nUnknown response - aborting\n";
                goto Fine;
            }
            
            # Dots
            if (($DonePages % 16) == 0)
            {
                print ".";
                system;
            }
        }
    }
    $DonePages *= $RecLen;
    print " done ($DonePages bytes)\n";
}
system;


#___________________________________________________________________Program Data
if ($optData ne "")
{
    my $i;
    my $g;
    my $isTobeProg;
    my $riga;
    my $len;
    my $offset;

    my $TOP_ADDR = 0x1000;          # 4Kb

    # Fill the ROM with "00"
    for ($i = 0 ; $i < $TOP_ADDR; $i++)
    {
        $strRomImage[$i] = "00";
    }

    # Open data file (hex) and read it
    if (-e"$optData")
    {
        open SOURCE_FILE, "$optData" or die;
        while ($riga = <SOURCE_FILE>)
        {
            $riga = Trim($riga);
            
            # If EOF record end
            if ($riga eq ":00000001FF")
            {
                last;
            }
            
            $len = hex(substr($riga, 1, 2));
            $offset = hex(substr($riga, 3, 4));
            # If it is a data record, read it
            if ( (hex(substr($riga, 7, 2))) == 0 )
            {
                for ($i = 0; $i < $len; $i++)
                {
                    if (($offset + $i) < $TOP_ADDR)
                    {
                        $strRomImage[$offset + $i] = substr($riga, (9 + ($i * 2)), 2);
                    }
                    else
                    {
                        print "The HEX file exceeds the device data ROM dimension: programming interrupted.\n";
                        close SOURCE_FILE;
                        goto Fine;
                    }
                }
            }
        }
        close SOURCE_FILE;
    }
    else
    {
        print "The $optData file does not exist\n";
        goto Fine;
    }

    # Program data
    print "Programming device data ROM ...";
    for ($i = 0; $i < $TOP_ADDR; $i += $DataPageLen)
    {
        $offset = strDecToHex24($i/4);          # page offset !!!
        $len = strDecToHex8($DataPageLen+4);    # includes command and 24bit address
        $riga = $len."45".$offset;              # "45" is the hex ascii code for 'E'
        
        $isTobeProg = 0;
        for ($g = 0; $g < $DataPageLen; $g++)
        {
            $riga = $riga.$strRomImage[$i + $g];
            if ($strRomImage[$i + $g] ne "00")
            {
                $isTobeProg = 1;
            }
        }
        
        # If it is a page to be programmed, send it
        if ($isTobeProg)
        {
            $riga = &strAddCheckSum($riga);
            $ob->write(chr(0x07));
            $ob->write(chr(0x0E));
            for ($g = 0; $g < length($riga); $g += 2)
            {
                $ob->write(chr(hex(substr($riga, $g, 2))));
            }
            
            $Res = &strWaitACK();
            if ($Res eq $ACK)
            {
                print ".";
            }
            elsif ($Res eq $NACK)
            {
                print " NACK\nProgramming Data: failed\n";
                goto Fine;
            }
            else
            {
                print " X\nUnknown response - aborting\n";
                goto Fine;
            }
        }
    }
    print " done\n";
}
system;


#________________________________________________Custom Bootlader ENABLE/DISABLE
if ($optBootload ne "")
{
    my $riga;
    my $g;

    if (($optBootload eq "E") || ($optBootload eq "e"))
    {
        print "Enabling Custom Bootloader Start Address ... ";
        $riga = "02"."46"."FE";              # "46" is the hex ascii code for 'F'
        $riga = &strAddCheckSum($riga);
        $ob->write(chr(0x07));
        $ob->write(chr(0x0E));
        for ($g = 0; $g < length($riga); $g += 2)
        {
            $ob->write(chr(hex(substr($riga, $g, 2))));
        }
        $Res = &strWaitACK();
        if ($Res eq $ACK)
        {
            print "done\n";
        }
        elsif ($Res eq $NACK)
        {
            print "FAILED\n";
            goto Fine;
        }
    }
    elsif (($optBootload eq "D") || ($optBootload eq "d"))
    {
        print "Disabling Custom Bootloader Start Address ... ";
        $riga = "02"."46"."FF";              # "46" is the hex ascii code for 'F'
        $riga = &strAddCheckSum($riga);
        $ob->write(chr(0x07));
        $ob->write(chr(0x0E));
        for ($g = 0; $g < length($riga); $g += 2)
        {
            $ob->write(chr(hex(substr($riga, $g, 2))));
        }
        $Res = &strWaitACK();
        if ($Res eq $ACK)
        {
            print "done\n";
        }
        elsif ($Res eq $NACK)
        {
            print "FAILED\n";
            goto Fine;
        }
    }
    else
    {
        print "Bad option: --bootloader accepts only arguments E(nable) or D(isable)\n";
    }
}


#_______________________________________________________________Program Security
if ($optSecurity ne "")
{
    print "Security programming not available yet - under development\n";
}


#____________________________________________________________________Run Program
if ($optRun ne "")
{
    my $riga;
    my $g;

    $optRun = strDecToHex24(hex($optRun));
    $riga = "04"."55".$optRun;                  # "55" is the hex ascii code for 'U', "04" is the data len

    $riga = &strAddCheckSum($riga);

    print "Remote RUN ... ";

    $ob->write(chr(0x07));
    $ob->write(chr(0x0E));
    for ($g = 0; $g < length($riga); $g += 2)
    {
        $ob->write(chr(hex(substr($riga, $g, 2))));
    }

    $Res = &strWaitACK();
    if ($Res eq $ACK)
    {
        print "done\n";
    }
    elsif ($Res eq $NACK)
    {
        print "NACK: failed\n";
        goto Fine;
    }
    else
    {
        print "Unknown response - aborting\n";
        goto Fine;
    }
}
system;


Fine:
undef $ob;
exit;
#_______________________________________________________________Main Program END




sub strWaitResponse
# ------------------------------------------------------------------------------
# Wait for a response with timeout
# ------------------------------------------------------------------------------
{
my $timeout = 20;
my $chars = 0;
my $buffer = "";
my @SplitBuf;

    $ob->read_interval(100) if ($OS_win);
    $ob->read_const_time(50);
    $ob->read_char_time(1);

    while ($timeout > 0)
    {
        my ($count,$saw) = $ob->read(255);    # will read _up to_ 255 chars
        if ($count > 0)
        {
            $chars+=$count;
            $buffer.=$saw;
            # Check here to see if what we want is in the $buffer
            # say "last" if we find it
            if ($buffer =~ "\n")
            {
                system;
                @SplitBuf = split("\n", $buffer);
                return &Trim($SplitBuf[0]);
            }
        }
        else
        {
            $timeout--;
        }
    }
}


sub strWaitACK
# ------------------------------------------------------------------------------
# Wait for ACK/NACK with timeout
# ------------------------------------------------------------------------------
{
my $timeout = 100;
my $chars = 0;
my $buffer = "";

    $ob->read_interval(100) if ($OS_win);
    $ob->read_const_time(10);
    $ob->read_char_time(0);

    while ($timeout > 0)
    {
        my ($count,$saw) = $ob->read(255);    # will read _up to_ 255 chars
        if ($count > 0)
        {
            $chars+=$count;
            $buffer.=$saw;
            # Check here to see if what we want is in the $buffer
            # say "last" if we find it
            if ($buffer eq chr($ACK))
            {
                return $ACK;
            }
            elsif ($buffer eq chr($NACK))
            {
                return $NACK;
            }
        }
        else
        {
            $timeout--;
        }
    }
    print "timeout\n";
}


sub Trim
# ------------------------------------------------------------------------------
# Correspondent to BASIC "trim" function
# ------------------------------------------------------------------------------
{
    my $string = shift;
    chomp($string);
    for ($string)
    {
        s/^\s+//;
        s/\s+$//;
    }
    return $string;
}


sub strDecToHex8
# ------------------------------------------------------------------------------
# Convert a number into a 2 char ASCII HEX
# ------------------------------------------------------------------------------
{
    my $hexnum;
    $hexnum = sprintf("%2.2x", shift);  # Converts the number in a 2-char string, HEX format
    $hexnum =~ tr/a-z/A-Z/;             # Uppercase
    return $hexnum;
}


sub strDecToHex16
# ------------------------------------------------------------------------------
# Convert a number into a 4 char ASCII HEX
# ------------------------------------------------------------------------------
{
    my $hexnum;
    $hexnum = sprintf("%4.4x", shift);  # Converts the number in a 4-char string, HEX format
    $hexnum =~ tr/a-z/A-Z/;             # Uppercase
    return $hexnum;
}


sub strDecToHex24
# ------------------------------------------------------------------------------
# Convert a number into a 6 char ASCII HEX
# ------------------------------------------------------------------------------
{
    my $hexnum;
    $hexnum = sprintf("%6.6x", shift);  # Converts the number in a 6-char string, HEX format
    $hexnum =~ tr/a-z/A-Z/;             # Uppercase
    return $hexnum;
}


sub strAddCheckSum
# ------------------------------------------------------------------------------
# Add a checksum (Intel HEX record format) to the given string
# ------------------------------------------------------------------------------
{
    my $crc;
    my $i;
    my $arg;

    $arg = shift;
    $crc = 0;
    for ($i = 0; $i < length($arg); $i += 2)
    {
        $crc = $crc + hex(substr($arg, $i, 2));
        if ($crc > 255)
        {
            $crc = $crc % 256;
        }
    }

    $crc = (256 - $crc);
    if ($crc == 256)
    {
        $crc = 0;
    }
    $crc = strDecToHex8($crc);

    return $arg.$crc;
}


