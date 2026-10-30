function g = kidsFeedbackLayout(winRect, fb)
%KIDSFEEDBACKLAYOUT Geometry of the child's feedback screen (pure, no Screen).
%   g = kidsFeedbackLayout(winRect, fb)   fb from kidsFeedbackBeat
%
%   Everything of kidsQuestionLayout (the cards stay where the question showed them),
%   plus:
%     goldColour
%     gold, goldWidth    outer edge and line width of the thick gold frame round the
%                        correct card (just outside its white frame position)
%     chosenFrame, chosenWidth   the white frame on the chosen card (as when answered)
%     badge              [x y r]: the big star badge in the correct card's top right
%                        corner
%     tick               active (right answers), points (3 x 2: the big tick in the
%                        chosen card's top left corner, scaled by fb.tick), width
%     fadeChosen         active (wrong answers), rect (the chosen card and its label,
%                        inside its white frame, which stays), alpha (fb.fade)
H = winRect(4) - winRect(2);
g = kidsQuestionLayout(winRect);
g.goldColour = [1 0.78 0.12];
g.goldWidth = 0.016 * H;
g.gold = g.frame.(fb.truth) + [-1 -1 1 1] * g.goldWidth;
g.chosenFrame = g.frame.(fb.answer);
g.chosenWidth = g.chosenWidth;
c = g.card.(fb.truth); L = c(3) - c(1);
g.badge = [c(3) - 0.13 * L, c(2) + 0.13 * L, 0.11 * L];

% the tick: top left of the chosen card, clear of the monster and the mouse (the
% truth stays visible), opposite the badge
ch = g.card.(fb.answer); Lc = ch(3) - ch(1);
centre = [ch(1) + 0.17 * Lc, ch(2) + 0.15 * Lc];
k = max(fb.tick, 0.001);                        % pops in from its centre
shape = [-0.1 0.0; -0.03 0.075; 0.12 -0.1] * Lc;   % short stroke down, long stroke up
g.tick = struct('active', fb.correct, 'points', centre + k * shape, 'width', 0.045 * Lc * k);
g.fadeChosen = struct('active', ~fb.correct, 'rect', g.frame.(fb.answer) + [1 1 -1 -1] * g.chosenWidth, 'alpha', fb.fade);
end
