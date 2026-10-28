function k = KbName(name)
names = {'ESCAPE', 'space', 'LeftArrow', 'RightArrow', 'Return', '1!', '2@', '3#'};
codes = [27 32 37 39 13 49 50 51];
if strcmpi(name, 'UnifyKeyNames'), k = []; return; end
k = codes(strcmpi(names, name));
end
