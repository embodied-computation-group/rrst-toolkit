classdef flowRecord < handle
%FLOWRECORD Growing store of [t flowSlm] rows: what a flow source has handed out.
%   r = flowRecord()     empty
%   r.append(s)          add the N-by-2 rows s at the end
%   x = r.data()         every row so far, in order (0-by-2 if none)
%   Used by flowInlet and kidsSimFlow when src.record is true (standalone recording).
%   The buffer is allocated FirstRows at a time (10 min at 1 kHz) and doubles when
%   full, so a 20-minute session (about 1.2 million rows) grows it twice.

    properties (SetAccess = private)
        n = 0                        % rows stored
    end

    properties (Access = private)
        buf = zeros(0, 2)
    end

    properties (Constant)
        FirstRows = 600000
    end

    methods
        function append(r, s)
            m = size(s, 1);
            if m == 0
                return
            end
            need = r.n + m;
            if need > size(r.buf, 1)
                r.buf(max([need, 2 * size(r.buf, 1), r.FirstRows]), 2) = 0;
            end
            r.buf(r.n + 1:need, :) = s;
            r.n = need;
        end

        function x = data(r)
            x = r.buf(1:r.n, :);
        end
    end
end
