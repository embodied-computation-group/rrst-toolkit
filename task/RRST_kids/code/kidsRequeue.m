function kp = kidsRequeue(kp)
%KIDSREQUEUE Skip the current trial (no answer, or a bad breath) and repeat its type at the end.
%   kp = kidsRequeue(kp)   Psi is not updated.
kp.schedule(end + 1) = kp.schedule(kp.k);
kp.k = kp.k + 1;
kp.nRepeats = kp.nRepeats + 1;
end
