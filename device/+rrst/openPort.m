function port = openPort(portName, baudRate)
%OPENPORT Open the serial connection to a real RRST device.
%   port = rrst.openPort("COM5")
%
%   The Teensy 4.0 uses USB CDC, so the baud rate has no effect on speed (115200
%   matches the firmware's Serial.begin). The firmware treats a host that doesn't
%   assert DTR as disconnected and aborts any seek or move. This function asserts
%   DTR explicitly. NOT YET VERIFIED ON HARDWARE (see VERIFICATION.md).

if nargin < 2
    baudRate = 115200;
end
port = serialport(portName, baudRate, "Timeout", 10);
configureTerminator(port, "LF");
setDTR(port, true);
pause(0.1);
flush(port);
end
