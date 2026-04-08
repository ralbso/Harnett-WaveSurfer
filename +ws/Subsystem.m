classdef (Abstract) Subsystem < ws.Model
    % Default base class for WaveSurfer subsystem implementations.
    % Defines the subsystem API with default (no-op) lifecycle methods.
    
    properties (Dependent = true)
        IsEnabled
    end
    
    properties (Access = protected)
        IsEnabled_ = false
    end
    
    methods
        function self = Subsystem()
            self@ws.Model() ;
        end
                
        function out = get.IsEnabled(self)
            out = self.getIsEnabledImplementation();
        end
        
        function set.IsEnabled(self, value)
            self.setIsEnabledImplementation_(value);
        end
        
        function completingRun(self) %#ok<MANU>
        end
        
        function stoppingRun(self) %#ok<MANU>
        end
        
        function abortingRun(self) %#ok<MANU>
            % Called if a failure occurred during startingRun().
            % This code MUST be exception free.
        end
        
        function startingSweep(~)
        end
        
        function completingSweep(~)
        end
        
        function stoppingSweep(~)
        end
        
        function abortingSweep(~)
            % Called when a sweep is interrupted.
            % This code MUST be exception free.
        end

        function mimicWavesurferModel_(self, other)
            % Sync satellite settings to the WavesurferModel settings.
            self.mimic(other) ;
        end
    end
    
    methods (Access = protected)
        function out = getIsEnabledImplementation(self)
            out = self.IsEnabled_;
        end
        
        function setIsEnabledImplementation_(self, newValue)
            if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                self.IsEnabled_ = logical(newValue) ;
                didSucceed = true ;
            else
                didSucceed = false ;
            end
            self.broadcast('Update') ;
            if ~didSucceed ,
                error('ws:invalidPropertyValue', ...
                      'IsEnabled must be a scalar, and must be logical, 0, or 1') ;
            end
        end
    end
    
end
