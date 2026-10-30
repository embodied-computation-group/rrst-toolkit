function closer = kidsOpenMarkers(cfg)
%KIDSOPENMARKERS Open the "RRST" LSL marker stream if cfg.markers.lsl (sends "RRST_ready").
%   closer = kidsOpenMarkers(cfg)   keep closer for the session; clearing it closes the stream.
%   With cfg.markers.lsl = false a stream left open by an earlier run is closed, so
%   every rrstMarker push is a no-op for LSL and liblsl need not be installed. Either
%   way the marker log (rrstMarker('log'), saved in standalone recording) starts empty.
rrstMarker('close');
rrstMarker('clearLog');
closer = onCleanup(@() rrstMarker('close'));
if cfg.markers.lsl
    rrstMarker('open', cfg.markers.liblslDir);
end
end
