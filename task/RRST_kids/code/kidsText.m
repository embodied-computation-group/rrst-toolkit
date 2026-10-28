function t = kidsText(language)
%KIDSTEXT Child-directed text. English only: translate before use with children
%   (Swiss German / Danish), keeping the sentences as short.
if language ~= "en"
    error('rrst:badConfig', 'Kids text exists only in English so far (got "%s").', language);
end
t.calibrating = 'Getting the straw ready...';
t.story = ['This is Milkshake Monster!\nIt loves milkshake.\n\n' ...
    'A cheeky mouse likes to pinch the straw.\nThen slurping feels squishy!'];
t.ready = 'Ready to slurp?';
t.cue = 'Ready...';
t.inhale = 'Big slurp!';
t.exhale = 'Ahhh...';
t.question = 'Did the mouse pinch the straw?';
t.easy = 'Easy';
t.squishy = 'Squishy!';
t.yesFeedback = 'Yes! The mouse pinched it!';
t.noFeedback = 'No mouse this time!';
t.star = 'A star!';
t.cupDone = 'Milkshake finished! Sticker time!';
t.rest = 'Little rest.\n\n%d';
t.pause = 'Pause';
t.sticker = 'All done! You were great!';
t.thanks = 'Thank you! All done for today.';
end
