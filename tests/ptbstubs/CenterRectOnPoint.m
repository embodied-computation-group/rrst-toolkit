function r = CenterRectOnPoint(r, x, y)
r = [x - r(3) / 2, y - r(4) / 2, x + r(3) / 2, y + r(4) / 2];
end
