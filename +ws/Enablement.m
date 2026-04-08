classdef Enablement < handle    
    % Class to keep track of the enablement state of something.
    % Supports nested disable/enable calls via a degree counter.
    
    properties (Access=protected)
        DegreeOfEnablement_ = 1
    end
    
    properties (Dependent=true, SetAccess=immutable)  
        IsEnabled   % logical scalar, read-only
    end

    methods
        function self=Enablement()
        end
        
        function enableMaybe(self)
            newDegreeOfEnablementRaw = self.DegreeOfEnablement_ + 1 ;
            self.DegreeOfEnablement_ = min(1,newDegreeOfEnablementRaw) ;
        end
        
        function disable(self)
            self.DegreeOfEnablement_ = self.DegreeOfEnablement_ - 1 ;
        end
        
        function value=get.IsEnabled(self)
            value = (self.DegreeOfEnablement_>0);
        end
        
        function value = peekAtDegreeOfEnablement(self)
            % For debugging only, not for routine access            
            value = self.DegreeOfEnablement_ ;
        end
    end
    
end
