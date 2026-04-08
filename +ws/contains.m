function result = contains(str, pattern)
    % DEPRECATED: This polyfill is no longer needed as of MATLAB R2016b+.
    % The built-in contains() function is used instead.
    % This file is kept only for backwards compatibility with external user code.
    error('ws:deprecatedFunction', ...
          'ws.contains() has been removed. Use the built-in contains() function instead.') ;
end
