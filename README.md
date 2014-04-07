# ADuC8xx Firmware Uploader

Analog Devices AD8xx family microcontrollers In System Programmer (ISP)

[aduc8xx home](http://www.precma.com/adux8xx_loader.htm)

Needs perl module [Device::SerialPort](http://sendpage.org/device-serialport)

**Supported devices**: ADUC812, ADUC814, ADUC816, ADUC824, ADUC831, ADUC832, ADUC834, ADUC836, ADUC841, ADUC842, ADUC843, ADUC845, ADUC847, ADUC848

See the aduc8xx.txt in the distribution for detailed info; here below the --help output of the program:
    # aduc8xx.pl --help
    ADuC8xx Programmer Version 1.3 (140401) - Copyright 2005-2014 PRECMA S.r.l.
    Usage: aduc8xx [--opt1 [arg1[,arg2]] ... --optn [arg1[,arg2]]]
    --help             Show options
    --detect [baud]    Try to initiate the communication at the given baudrate
      (default 9600baud, setting depends on your system clock - see aduc8xx.txt)
    --eflash           Erase Flash Memory
    --echip            Erase Flash & Data Memory
    --quickmode s,b    Change the programming baud rate: s=T3CON:T3FD b=baudrate
      (available for the Timer 3 enabled derivates only - see aduc8xx.txt)
    --program hexfile  Program in the flash ROM the given hexfile
    --data hexfile     Program in the data ROM the given hexfile
    --security [mode]  Set Security mode (6=LOCK, 5=SECURE, 4=LOCK+SECURE (default),
                       3=SERIAL SAFE, 2=SERIAL SAFE+LOCK, 1=SERIAL SAFE+SECURE,
                       0=SERIAL SAFE+SECURE+LOCK)
    --bootload [E/D]   Enable (E) or disable (D) the custom bootloader startaddress
    --run hexaddr      Execute user code from addr (hex)
    --port p           Define serial port to use (i.e. /dev/ttyS0)
    Bootloader is initiated by the --detect option and stopped by the --run option
    Examples:
    aduc8xx.pl --detect --echip --program dummy.hex --run 0
      Erase chip, program it @9600baud and start the code
    aduc8xx.pl --detect --program dummy.hex --quickmode 8309,57600
      Erase chip, program it @57600baud (quickmode for ADuC842@32KHz)

[PRECMA S.r.l.](http://www.precma.com) - Fausto Marzoli

[Mirror repository](https://github.com/datacompboy/aduc8xx) on GIT.
