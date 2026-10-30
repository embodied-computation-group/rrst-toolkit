function g = kidsQuestionLayout(winRect)
%KIDSQUESTIONLAYOUT Geometry of the answer screen for a window rect (pure, no Screen).
%   g = kidsQuestionLayout(winRect)
%   Two landscape scene cards (5:4) of the same size, mirror images about the screen centre:
%   "no" (easy) on the left, "yes" (squishy) on the right. Rects are [left top right
%   bottom] in pixels; per-answer fields are structs with fields no and yes.
%     questionBand  [0 0 W bottom]   strip at the top for the experimenter's question
%     questionY     top of the question text
%     card          the scene cards
%     label         [centreX top] of each label, under its card
%     labelRect     box the label is centred in
%     frame         outer edge of the hover/chosen frame (card and label)
%     fade          area dimmed when the other answer was chosen
%     hit           [x0 x1] of the window that a click answers with; the middle strip
%                   between them is ignored (same 5 % as kidsClickAnswer)
%     lineWidth, chosenWidth   frame thickness when hovered / chosen
%     radius        corner radius of cards and frames
%   Everything scales with the window height; the card size is also capped by the
%   width, so 4:3 and portrait windows keep the cards apart and inside their halves.
W = winRect(3) - winRect(1); H = winRect(4) - winRect(2);
middle = 0.05;                              % half-width of the ignored strip (kidsClickAnswer)

g.questionBand = [0, 0, W, 0.10 * H];
g.questionY = 0.035 * H;
g.hit.no = [0, (0.5 - middle) * W];
g.hit.yes = [(0.5 + middle) * W, W];

pad = 0.02 * H;                             % card edge to frame edge
labelGap = 0.01 * H; labelH = 0.06 * H;
inner = (0.5 - middle - 0.02) * W - pad;    % card edge nearest the centre, frame kept off the strip
L = min(0.66 * H / 0.8, inner - 2 * pad);   % card width
cardH = 0.8 * L;
groupH = cardH + labelGap + labelH + 2 * pad;   % frame height
top = g.questionBand(4) + 0.02 * H;         % frames go between the band and the bottom margin
frameTop = top + (0.98 * H - top - groupH) / 2;
cardTop = frameTop + pad;

g.card.no = [inner - L, cardTop, inner, cardTop + cardH];
g.card.yes = [W - inner, cardTop, W - inner + L, cardTop + cardH];
g.lineWidth = 0.0035 * H;
g.chosenWidth = 0.01 * H;
g.radius = 0.03 * H;
for side = ["no" "yes"]
    c = g.card.(side); cx = (c(1) + c(3)) / 2;
    g.label.(side) = [cx, c(4) + labelGap];
    g.labelRect.(side) = [c(1), c(4) + labelGap, c(3), c(4) + labelGap + labelH];
    g.frame.(side) = [c(1) - pad, c(2) - pad, c(3) + pad, c(4) + labelGap + labelH + pad];
    g.fade.(side) = g.frame.(side) + [-1 -1 1 1] * 0.005 * H;
end
end
