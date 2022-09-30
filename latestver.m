function lv = latestver()
%  RELEASESTRING = LATESTVER()
%  Get the short release string for the latest version of MATLAB
%  This simply scrapes the string from webdocs pages and may not
%  always be accurate in the days near a new release.
%
%  Example:
%   >> latestver
%	latestver =
%       'R2021a'
%
%  See also: version

[S2 status] = urlread('https://www.mathworks.com/help/matlab/index.html');
if status
	S2 = regexp(S2,'((?<=src="\/help\/releases\/R20)(.*?)(?=\/includes\/))','match');
	if ~isempty(S2)
		lv = ['R20' S2{1}];
	else
		error('LATESTVER: Found no version string! This is probably because the url structure has changed.')
	end
else
	error('LATESTVER: Failed to fetch webdocs')
end