function stem = sessionFileStem(subNo, session, mock)
%SESSIONFILESTEM File name start for one session of one participant.
%   stem = sessionFileStem(subNo, session, mock)
%   sessionFileStem(1, 2, false) -> 'RRST_0001_s2'; mock -> 'MOCK_RRST_0001_s2'.
%   loadParams adds _<procedure>_<date>; endSession adds Aborted_ / Error_.
if ~(isscalar(session) && isnumeric(session) && session >= 1 && session == round(session))
    error('rrst:badSession', 'Session must be a whole number from 1 (got %s).', mat2str(session));
end
stem = sprintf('RRST_%04d_s%d', subNo, session);
if mock
    stem = ['MOCK_', stem];                 % never mistaken for real data
end
end
