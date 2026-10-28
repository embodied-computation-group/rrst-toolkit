function ok = isSerialportHandle(obj)
%isSerialportHandle True if obj is a MATLAB serialport object.
%
%   Input:
%       obj     any value
%   Output:
%       ok      true if obj is a serialport object, false otherwise
%
% isa(obj, 'serialport') is false for a real serialport object: its actual
% class is internal.Serialport (confirmed on R2023b and R2026b). Both names
% are accepted so this also works on releases where the class is reported
% as plain serialport.

ok = isa(obj, 'serialport') || isa(obj, 'internal.Serialport');
end
