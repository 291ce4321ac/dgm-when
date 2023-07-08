function when(func_name)
%  WHEN(FUNCTIONNAME)
%  Determine the version when the specified function was introduced to MATLAB.
%  Results are returned with the version number and a link to the webdocs page.
%  The specified function does not need to exist in the current installation.
%
%  When() determines the introduction version by scraping webdocs.  This has
%  unfortunate limitations and may break if the website formatting changes
%  significantly in the future.  See internal notes for more discussion.
%
%  Since when() uses webdocs, version info will only be returned if the named 
%  function exists in the current version of MATLAB.  There is no practical and 
%  general method to find introduction or removal dates for a function which has
%  been removed from MATLAB.  Keep that in mind if you're using an older version.
% 
%  Some attempt has been made to detect cases where a function has been renamed,
%  but due to multiple factors, the chances of correctly detecting these cases 
%  are very low.  Failure to detect a renaming event will result either in the 
%  absence of information relevant to the change, or a message inaccurately
%  indicating that the function has been removed.
%
%  FUNCTIONNAME specifies the function to look up. (case-insensitive)
%    This parameter may be a char vector or a cell array of char vectors.
%
%  Examples:
%   when('rand')
%   ## rand -- Introduced before R2006a
%
%   when createmask
%   ## imroi.createmask -- Introduced in R2008a
%   ## images.roi.assistedfreehand.createmask -- Introduced in R2018b
%   ## dicomcontours.createmask -- Introduced in R2020b
%
%   func_name = {'plot','urlread','webread','wavread','isgray','caxis'};
%   when(func_name)
%   ## plot -- Introduced before R2006a
%   ## urlread -- Introduced before R2006a
%   ## webread -- Introduced in R2014b
%   ## wavread -- Does not exist in this installation; no online documentation found
%				  If this is part of MATLAB, it may have been removed before R2019b
%   ## isgray -- Exists, but no online documentation found
%                Function may have been removed between R2019b and R2021a
%   ## clim -- Introduced before R2006a
%              caxis was renamed to clim in R2022a
%
% See also: which, whos

% Based on when() by Reza Ahmadzadeh (reza.ahmadzadeh@iit.it)
% https://www.mathworks.com/matlabcentral/fileexchange/54483-when-when-a-function-was-introduced-by-matlab
% Reworked by DGM to:
%	fix compatibility with changes to website formatting
%	allow lookup of functions not in the current installation (due to version or missing toolbox)
%	accomodate for functions where the webdocs URL cannot be naively predicted (e.g. createMask)
%   allow function name cell array to have any geometry
%   try to check for name changes

% When() determines the introduction version by scraping webdocs.  This has
% unfortunate limitations.  When() will attempt to guess the webdocs URL directly.
% When this succeeds, this is faster and compatible with older versions.  In the 
% case that there are multiple functions with the same name (e.g. in different
% toolboxes), this direct approach fails, and a websearch is performed.  All 
% matching webdocs are processed.  This websearch fallback requires +R2014b.
%
% The split direct/search approach has an unfortunate side-effect of causing (hopefully) minor inconsistency 
% in behavior.  Functions which have webdocs for multiple methods will only return multiple results if 
% none of the urls are an exact match for the function name (i.e. '.../functionname.html').  In this sense, 
% when() aims only for a mere sufficiency of disambiguation.  
%
% Considering the following factors:
%   - the ambiguity of content referenced by urls under /help/
%   - poor reliability enforcing exact searches with google
%   - the API allows only up to 10 results
% certain queries may fail to find relevant function webdocs.  This happens because the 
% results will be polluted with unwanted demo/overview pages, pushing the desired webdocs 
% outside the narrow search window.  This and the version dependency of webread()/weboptions() 
% are the primary reasons to avoid default use of the websearch method. 
%
% There are reference lists such as https://www.mathworks.com/help/matlab/referencelist.html?type=function
% but that's slow and would require JS and foreknowledge of the possible toolbox(es) to search in.
% Similarly, searching for docs using TMW support search tool is slow and requires JS to display results.
%
% The issue of function removal dates is difficult, as documentation generally does not exist for removed tools.
% The release notes do list some removed functions, but they're beyond problematic.
%
% The web version is a narrow rolling ~3 year window, which makes it mostly useless for the purpose.  
% This is compounded by the fact that the pages require JS in order to function, preventing practical scraping.
% The organization means you'd have to know where to find the function.  Otherwise, you'll need to check every toolbox
% page for every version, compounding the already obscenely slow access times.  
% 
% There are PDF release notes available back to ~R2012b, but as far as I can tell, the PDF release notes only cover 
% base MATLAB, but not all the toolboxes.  RN for other toolboxes may go back further; older copies can also occasionally be found.
%
% It might be possible to scrape either web or PDF RN now and build a lookup table for runtime use, but it would still 
% only cover core tools back to R2012b, and the rest of common toolboxes back to R2018a.  The task of scraping either 
% would be a maddening and unrewarding challenge requiring biannual maintenance for a result that's barely useful. 
% These features are something that only TMW is in any position to provide, and i'm in no position to request it.

% removed, but still has webdocs: hdftool(2020a)
% removed, and webdocs removed: isSingleReadPerFile(2020a), profilereport(2020b), isgray, isbw, isrgb, wavread

% the issue of renamed functions is another problem to resolve
% https://www.mathworks.com/help/matlab/ref/clim.html
% caxis() and clim() both redirect to the same page and return the same date (<R2006a)
% even though clim() was not available until R2022a
% these changes are mentioned in the header, but not consistently
% sometimes the date is missing; sometimes there's a note at the end of the page
%
% in this specific case, the url guessing works because the mathworks site redirects
% but if it were to fail and fallback to a web search, it would fail the websearch 
% because none of the results contain the queried function name
% there isn't a good way to detect renamed cases if this happens


forcesearch = false; % for testing

if ischar(func_name)
	checkFunctionName(func_name,forcesearch);
elseif iscell(func_name)
	for ii = 1:numel(func_name)
		fname = func_name{ii};
		checkFunctionName(fname,forcesearch);
	end
else
	error('WHEN: The input should be either a char vector or a cell array of chars.');
end
end % END MAIN SCOPE

function checkFunctionName(fname,forcesearch)
	fname = lower(fname);
	
	% i'm not doing any type checks on fname.  
	% it's unnecessary and causes problems which prevent valid queries
	% for example, checking functions which aren't included in the current installation

	if ~forcesearch
		% try guessing the url directly 
		% if this works, it's faster and compatible <R2006a
		% guessing and hoping for a redirect also improves our chances of finding renamed functions
		url = ['https://mathworks.com/help/matlab/ref/' fname '.html'];
		[str status] = urlread(url); %#ok<*URLRD> % webread() creates version dependency (R2014b)
		if ~status
			url = ['https://mathworks.com/help/simulink/slref/' fname '.html'];
			[str status] = urlread(url);
		end
		C = {str};
		FN = {fname};
		urllist = {url};
	end
	
	
	% if both guesses fail, switch to doing websearch (requires R2014b+)
	if forcesearch || ~status
		if ifversion('<','R2014b')
			error('WHEN: Unable to guess correct URL directly; fallback websearch method requires R2014b or newer.')
		end
		
		apikey = 'AIzaSyD6_GZ8BBo56pLdketbJG1xqYa7B8JkwoY';
		cx = '35ad73502cee43a8e';
		query = ['"' fname '"' '+site:www.mathworks.com/help/'];
		
		% DDG api can't handle specific queries (returns empty JSON obj for most queries)
		wopt = weboptions('contenttype','json');
		url = ['https://customsearch.googleapis.com/customsearch/v1?cx=' cx '&key=' apikey '&q=' query '&num=10'];

		try 
			S = webread(url,wopt);
		catch
			% this might also happen if no exact url exist and API call is broken somehow
			fprintf('Connection error.  Direct lookups and web searches all failed.\n')
			return;
		end

		if isfield(S,'items')
			urllist = {S.items(:).link}.';
			% only allow urls that end in '.fname.html' or '/fname.html'
			% no, i'm not using contains(), as it introduces version dependency (R2016b)
			% this will fail if the function has been renamed.  function will be reported as removed.
			urllist = urllist(~cellfun(@isempty,regexp(urllist,sprintf('(\\/|\\.)%s\\.html',fname),'start')));
		end
		
		if isempty(urllist) || ~isfield(S,'items') % no results found with any method
			% if function exists under $MLROOT/toolbox, assume it may have been removed since 
			tbroot = fullfile(matlabroot,'toolbox');
			fpath = which(fname);
			
			myver = ['R' version('-release')];
			if ~isempty(strfind(fpath,tbroot)) %#ok<*STREMP>
				try
					lver = latestver();
				catch
					lver = 'the latest version';
				end
				
				fprintf('## %s -- Exists, but no online documentation found\n',fname)
				fprintf('%sFunction may have been removed between %s and %s\n',repmat(' ',[1 numel(fname)+7]),myver,lver)
				return;
			else
				fprintf('## %s -- Does not exist in this installation; no online documentation found\n',fname)
				fprintf('%sIf this is part of MATLAB, it may have been removed before %s\n',repmat(' ',[1 numel(fname)+7]),myver)
				return;
			end
		end
		
		C = cell(numel(urllist),1);
		for k = 1:numel(urllist)
			C{k} = webread(urllist{k});
		end
		
		FN = regexp(urllist,'([^\/]+(?=.html))','match');
		FN = vertcat(FN{:});
	end
	
	% scrape document(s) for version info, print to console
	for c = 1:numel(C)
		str = C{c};
		fname = FN{c};
		
		% get the main release version info string
		outstr = regexp(str,'>(Introduced \w+ R20\d{2}(a|b))<','tokens');
		
		% there are so few examples of renamed functions that it's hard to expect formatting 
		% to be consistent enough for this to be reliable
		% there are some classes for which this doesn't work, 
		% but let's not overcomplicate something that can never be robust
		renameexpr = ['<span class="icon\-arrow\-open\-right"></span>(R20\d{2}(a|b)): ' ...
					  '<span class="remove_bold">Renamed from <code class="literal">(\w+)</code>'];		
		renamemsg = regexp(str,renameexpr,'tokens');
		
		% need to get actual current name, since fname/urllist are derived from user input
		% afnexpr = '<title>.+- MATLAB (\w+)</title>'; % doesn't always work
		afnexpr = '<link rel="canonical" href="http[:/\w\.]+/([^/]+).html'; % try this
		actualfname = regexp(str,afnexpr,'tokens');
		if ~isempty(actualfname)
			fname = actualfname{1}{1};
		end
		
		if isempty(outstr)
			% page exists, but can't find release info
			outstr = 'No release information found on webdocs page';
			fprintf('## <a href="%s">%s</a> -- %s\n',urllist{c},fname,outstr);
		else
			% release info found
			fprintf('## <a href="%s">%s</a> -- %s\n',urllist{c},fname,outstr{1}{1});
			
			if ~isempty(renamemsg)
				% rename info found
				offsetblock = repmat(' ',[1 numel(fname)+7]);
				if isempty(actualfname)
					% if the actual fname isn't reliably known, this just simplifies the output in cases
					% where a guessed fname is the same as the old fname.  in that scenario,
					% the default output would result in "x was renamed to x" which is pointless and confusing.
					% returning just "x was renamed" is ambiguous, but it's the sum of available information.
					% bear in mind that rename detection cannot occur unless the url was guessed and redirected
					% so if we're here, fname in FN comes from user input, not from the url (what a mess!)
					fprintf('%s%s was renamed in %s\n',offsetblock,renamemsg{1}{2},renamemsg{1}{1});
				else
					fprintf('%s%s was renamed to %s in %s\n',offsetblock,renamemsg{1}{2},fname,renamemsg{1}{1});
				end
			end
		end
	end

end


