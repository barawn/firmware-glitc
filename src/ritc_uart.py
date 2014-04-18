import qnd
import serial
import time
import sys


## Registers
dac_low = 4
dac_high = 5
dac_address = 6
dac_load = 7
vcdl_control = 16
train = 17
refclk_counter_low = 18
refclk_counter_high = 19
delay_value = 0
delay_addr_control = 1
phase_control = 8
phase_select = 9
phase_arg_low = 10
phase_arg_high = 11
phase_res_low = 12
phase_res_high = 13
phase_servo_low = 14
phase_servo_high = 15
## Phase scan commands.
cmdIdle = 0
cmdLocateTargetEdge = 1
cmdRealignScan = 2
cmdSpecifyDutyMin = 3
cmdSpecifyDutyMax = 4
cmdSpecifyDutySums = 5
cmdDoDutyCycleCalc = 6
cmdSpecifyServoMin = 7
cmdSpecifyServoMax = 8
cmdDoServo = 9
cmdDoSimpleScan = 10
cmdDoServoCalc = 11
cmdRealignOriginal = 12


# Registers:
# 0 : DAC value low
# 1 : DAC value high
# 2 : DAC address
# 3 : DAC loading
# 4 : RITC refclock counter low
# 5 : RITC refclock counter high: bit 7 is STOP_VCDL
# 6 : [4:0] delay value, [7:5] delayctrl ready
# 7 : [5:0] delay address, [6] load delay [7] reset datapath
# 8 : phase scan control: [0] do_scan [1] do_monitor [2] new monitor
#                         [3] new dutycycle [5] do_skip
# 9 : phase scan select
# 10: monitor tap low
# 11: monitor tap high
# 12: monitor value low
# 13: monitor value high
# 14: dutycycle value low
# 15: dutycycle value high

device = qnd.QnD( '/dev/com4' )

# Reset datapath, IDELAYCTRLs, etc.
def resetAll():
    # Stop VCDL.
    device.writeRegister( vcdl_control, int(0x80) )
    # Restart VCDL.
    device.writeRegister( vcdl_control, 0)
    # Check the IDELAYCTRL 'RDY' values
    rdy = device.readRegister( delay_value )
    rdy = rdy >> 5
    # Check for refclock inversion.
    val = device.readRegister(refclk_counter_high)
    val = val >> 2
    print "Reset complete: IDELAYCTRL RDY = %x, REFCLK invert = %x" % (rdy, val)

# Choose which channel (0-2) and which bit (0-11) to scan.
def selectBit( channel, bit ):
    toWrite = (channel << 6) + (channel << 4) + bit
    device.writeRegister( phase_select , toWrite)

# Set the delay of a bit in a channel. 'bit 15' is the reference clock.
def setDelay( channel, bit, delay ):
    device.writeRegister( delay_value, delay )
    # The address works out to be "channel << 4" + bit.
    toWrite = (channel << 4) + bit
    device.writeRegister( delay_addr_control, toWrite )
    # And now issue the load as well. This is probably unimportant,
    # we could probably do both at the same time.
    device.writeRegister( delay_addr_control, toWrite | 0x40 )
    device.writeRegister( delay_addr_control, toWrite )

# Enable the scanner (in simple scan mode).
def setScanEnable( en ):
    if en == 0:
        device.writeRegister(8, 0)
    else:
        device.writeRegister(8, cmdDoSimpleScan)

def loadAllDACs():
    device.writeRegister(dac_load, 2)

# Update a DAC.
def updateDAC( address, value, load = 0 ):
    device.writeRegister(dac_low, value & 0xFF)
    device.writeRegister(dac_high, (value & 0xFF00)>>8)
    device.writeRegister(dac_address, address)
    device.writeRegister(dac_load, 1)
    if load != 0:
        device.writeRegister(dac_load, 2)

# Update the VCDL registers.
def setVCDL( Vdd , Vss ):
    updateDAC( 32, Vss )
    updateDAC( 31, Vdd, 1)

# Read the reference clock counter value.
def readScaler():
    lowByte = device.readRegister(refclk_counter_low)
    highByte = device.readRegister(refclk_counter_high) & 0x3
    scaler = (highByte << 8) + lowByte
    return scaler

# Read the training pattern (for the bit selected in selectTrainBit)
def readTrain():
    return device.readRegister( train )

# Select the channel/bit for training pattern readout.
def selectTrainBit(channel, bit):
    toWrite = (channel << 4) + bit
    device.writeRegister( train, toWrite)

# Issue BITSLIP to a given channel/bit.
def bitslip(channel, bit):
    toWrite = (channel << 4) + bit
    device.writeRegister( train, toWrite)
    device.writeRegister( train, toWrite | int(0x80))

def alignAllBits():
    for i in xrange(0,12):
        eyeScan(0,i,0)
        eyeScan(1,i,0)
        eyeScan(2,i,0)

# Scan for the eye in a given channel, and set it to the middle.
# Also bitslip the channel until it matches '0x53', the training pattern.
# (n.b.: this is the training pattern because the top nybble is *old*,
# and the LSB is oldest. So this, aligned in time, is 10101100.)
def eyeScan( channel, bit, verbose=1 ):
    selectTrainBit(channel, bit)
    setDelay(channel, bit, 0)
    start_train = readTrain()
    eyeStart = 0
    eyeStop = 0
    current_train = start_train
    test_train = 0
    newValueLength = 0
    foundEyeStart = 0
    trainInEye = 0
    for i in xrange(0,32):
        setDelay(channel, bit, i)
        test_train = readTrain()
        if test_train != current_train:
            current_train = test_train
            if foundEyeStart == 1 and eyeStop == 0:                
                eyeStop = i
            elif foundEyeStart == 0:
                eyeStart = i
        else:
            if eyeStart != 0 and foundEyeStart == 0:
                newValueLength = newValueLength + 1
                if newValueLength > 5:
                    trainInEye = test_train
                    foundEyeStart = 1
    eyeCenter = (eyeStart + eyeStop)/2
    if verbose == 1:
        print "Eye: %d - %d" % (eyeStart, eyeStop)
        print "Train in eye: %x" % trainInEye
        print "Centering at tap %d" % eyeCenter
    setDelay(channel, bit, eyeCenter)
    wantTrain = int(0x53)
    for i in xrange(0, 8):
        if trainInEye == wantTrain:
            break
        bitslip(channel, bit)
        trainInEye = readTrain()
        if verbose == 1:
            print "New train in eye: %x" % trainInEye
    trainInEye = readTrain()
    if trainInEye != wantTrain:
        print "Error! Could not find aligned training pattern! (%x)" % trainInEye

# Find edge. 'Channel 0' is the clock, 1 is the data, 2 is VCDL.
# (Clock/data selected by 'selectBit').
def findEdge( channel, startTap = 0 , averages = 1):
    edgeVal = 0
    for i in xrange(0,averages):
        toWrite = startTap + (channel << 10)
        device.writeRegister(phase_arg_low, toWrite & 0xFF)
        device.writeRegister(phase_arg_high, (toWrite & 0xFF00)>>8)
        device.writeRegister(phase_control, cmdLocateTargetEdge)
        edge = device.readRegister(phase_res_low)
        edge += (device.readRegister(phase_res_high)<<8)
        edgeVal += edge
    return edgeVal/float(averages)

# Find the edge of VCDL, and realign the scan with it.
# (minus 10 to give us SOME headroom).
def alignScanWithVCDL():
    # VCDL is channel 2 in the scanner (0 is clock, 1 is data).
    edge = findEdge( 2, 0 )
    print "VCDL edge is at %d" % edge
    if edge > 20:
        edge = int(edge - 10)
        print "Realigning to %d" % edge
        device.writeRegister(phase_arg_low, edge & 0xFF)
        device.writeRegister(phase_arg_high, (edge & 0xFF00)>>8)
        device.writeRegister(phase_control, cmdRealignScan)
    else:
        print "Scan is already within alignment tolerance."

# Test the servo calculation.
def testServoCalc():
    device.writeRegister(phase_control, cmdDoServoCalc)
    time.sleep(0.1)
    result = device.readRegister(14)
    result += device.readRegister(15) << 8
    return result

# Set the servo parameters.
def setServoParameters( min, max ):
    device.writeRegister(phase_arg_low, min & 0xFF)
    device.writeRegister(phase_arg_high, (min&0xFF00)>>8)
    device.writeRegister(phase_control, cmdSpecifyServoMin)
    device.writeRegister(phase_arg_low, max & 0xFF)
    device.writeRegister(phase_arg_high, (max&0xFF00)>>8)    
    device.writeRegister(phase_control, cmdSpecifyServoMax)

# Set the servo enable: 0 is disable, 1 is enable, 2 is debug.
def setServoEnable( en ):
    device.writeRegister(phase_arg_low, en & 0xFF)
    device.writeRegister(phase_arg_high, (en & 0xFF00)>>8)
    device.writeRegister(phase_control, cmdDoServo)

# Read last servo measurement.
def readServo():
    servo = device.readRegister(14)
    servo += device.readRegister(15)<<8;
    return servo

