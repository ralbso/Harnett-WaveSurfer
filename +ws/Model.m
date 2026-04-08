classdef (Abstract) Model < ws.Coding & ws.EventBroadcaster
    events
        Update  % Means that any dependent views need to update themselves
    end
    
    methods
        function self = Model()
        end
        
        function delete(self)  %#ok<INUSD>
        end
        
        function mimic(self,other)
            % Disable broadcasts for speed, then re-sync from other
            self.disableBroadcasts();
            self.mimic@ws.Coding(other);
            self.enableBroadcastsMaybe();
            self.broadcast('Update');
        end

        function propNames = listPropertiesForHeader(self)
            propNamesRaw = listPropertiesForHeader@ws.Coding(self) ;            
            propNames=setdiff(propNamesRaw, ...
                              {'IsReady'}) ;
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end
        
        function result = get(self, propertyName) 
            result = self.(propertyName) ;
        end
        
        function set(self, propertyName, newValue)
            self.(propertyName) = newValue ;
        end           
    end
    
end
