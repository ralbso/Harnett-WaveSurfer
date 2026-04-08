function raiseDialogOnException(exception)
    % Display an error or warning dialog for the given exception.
    % Shows the full cause chain for better debuggability.
    
    isWarning = startsWith(exception.identifier, 'ws:warningsOccurred') ;
    
    if isWarning ,
        dialogContentString = exception.message ;
        dialogTitleString = ws.fif(length(exception.cause)<=1, 'Warning', 'Warnings') ;
    else
        % Build up a message that includes the full cause chain
        parts = {exception.message} ;
        causes = exception.cause ;
        for i = 1:length(causes) ,
            parts{end+1} = causes{i}.message ;  %#ok<AGROW>
            % Follow nested causes
            nestedCauses = causes{i}.cause ;
            for j = 1:length(nestedCauses) ,
                parts{end+1} = nestedCauses{j}.message ;  %#ok<AGROW>
            end
        end
        dialogContentString = strjoin(parts, sprintf('\n')) ;
        
        % Include the error identifier for debuggability
        if ~isempty(exception.identifier)
            dialogContentString = sprintf('%s\n\n[%s]', dialogContentString, exception.identifier) ;
        end
        
        dialogTitleString = 'Error' ;
    end
    
    ws.errordlg(dialogContentString, dialogTitleString, 'modal') ;                
end
