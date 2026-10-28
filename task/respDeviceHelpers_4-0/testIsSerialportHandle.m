function tests = testIsSerialportHandle
%testIsSerialportHandle Unit tests for isSerialportHandle.m
%   Run with: runtests('testIsSerialportHandle')
%   The real-port test is skipped unless a Teensy is attached.
tests = functiontests(localfunctions);
end

function testRejectsNonPorts(testCase)
verifyFalse(testCase, isSerialportHandle(NaN));
verifyFalse(testCase, isSerialportHandle([]));
verifyFalse(testCase, isSerialportHandle("COM5"));
verifyFalse(testCase, isSerialportHandle(struct()));
end

function testAcceptsRealSerialport(testCase)
ports = serialportlist("available");
ports = ports(contains(ports, ["usbmodem", "COM"]));
assumeNotEmpty(testCase, ports, 'No serial device attached - skipping.');
p = serialport(ports(1), 115200);
cleanup = onCleanup(@() delete(p));
verifyTrue(testCase, isSerialportHandle(p));
end

function testCloseAndRecalibrateRejectNonPorts(testCase)
verifyEqual(testCase, evalc('closeResp(NaN)'), ...
    sprintf('closeResp: no valid serial connection to close.\n'));
[out, init] = evalc('recalibrateResp(NaN)');
verifyEqual(testCase, init, 0);
verifyTrue(testCase, contains(out, 'no valid serial connection'));
end

function assumeNotEmpty(testCase, v, msg)
assumeTrue(testCase, ~isempty(v), msg);
end
