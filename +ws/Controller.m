classdef Controller < handle

    properties (Dependent=true, SetAccess=immutable)
        Parent
        Model
        Figure  % the associated figure object (an MCOS handle, not an HG handle)
    end
    
    properties (Access=protected)
        Parent_
        Model_
        Figure_
    end
        
    methods
        function self = Controller(parent,model)        
            self.Parent_ = parent ;
            self.Model_ = model ;
        end
        
        function delete(self)
            if ~isempty(self.Figure) && isvalid(self.Figure) ,
                delete(self.Figure) ;
            end
            self.Model_ = [] ;  
              % We don't generally delete the model b/c most controllers are
              % sub-controllers whose model is a sub-model of the main model.
            self.Parent_=[];            
        end
        
        function output=get.Figure(self)
            output = self.Figure_ ;
        end

        function output=get.Parent(self)
            output=self.Parent_;
        end
        
        function output=get.Model(self)
            output = self.Model_ ;
        end
        
        function setAreUpdatesEnabledForFigure(self,newValue)
            self.Figure.AreUpdatesEnabled = newValue ;
        end        
    end
    
    methods
        function updateFigure(self)             
            self.Figure.update();
        end
        
        function showFigure(self)             
            self.Figure.show();
        end
        
        function hideFigure(self)
            self.Figure.hide();
        end
        
        function raiseFigure(self)
            self.Figure.raise();
        end 
    end
            
    methods (Access = protected)
        function deleteModel_(self)
            delete(self.Model_) ;
        end
        
        function deleteFigure_(self)
            figure = self.Figure ;
            if ~isempty(figure) && isvalid(figure) ,
                delete(figure) ;
            end
        end            
    end
    
    methods (Access = protected, Sealed = true)
        function layoutForAllWindows = addThisWindowLayoutToLayout(self, layoutForAllWindows)
            thisWindowLayout = self.encodeWindowLayout_();
            layoutVarNameForClass = ws.Controller.layoutVariableNameFromControllerClassName(class(self));
            layoutForAllWindows.(layoutVarNameForClass)=thisWindowLayout;
        end
    end
        
    methods (Access = protected)
        function layout = encodeWindowLayout_(self)
            fig = self.Figure ;
            position = get(fig, 'Position') ;
            visible = get(fig, 'Visible') ;
            if ischar(visible) ,
                isVisible = strcmpi(visible,'on') ;
            else
                isVisible = visible ;
            end
            layout = struct('Position', {position}, 'IsVisible', {isVisible}) ;
        end
    end
    
    methods (Access = protected)
        function decodeWindowLayout(self, layoutOfWindowsInClass, monitorPositions)
            figureObject = self.Figure ;
            fieldNames = fieldnames(layoutOfWindowsInClass) ;
            if isscalar(fieldNames) ,
                % Older protocol file format
                fieldName = fieldNames{1} ;
                layoutOfThisWindow = layoutOfWindowsInClass.(fieldName) ;
                isVisibleFieldName = 'Visible' ;
            else
                % Newer protocol file format
                layoutOfThisWindow = layoutOfWindowsInClass ;
                isVisibleFieldName = 'IsVisible' ;
            end
            if isfield(layoutOfThisWindow, 'Position') ,
                rawPosition = layoutOfThisWindow.Position ;
                set(figureObject, 'Position', rawPosition);
                figureObject.constrainPositionToMonitors(monitorPositions) ;
            end
            if isfield(layoutOfThisWindow, isVisibleFieldName) ,
                set(figureObject, 'Visible', layoutOfThisWindow.(isVisibleFieldName)) ;
            end
        end
    end
    
    methods
        function windowCloseRequested(self, source, event)
            shouldStayPut = self.shouldWindowStayPutQ(source, event);
            if ~shouldStayPut ,
                self.hideFigure();
            end
        end
    end

    methods (Access = protected)
        function shouldStayPut = shouldWindowStayPutQ(self, varargin)
            % Returns true if the window should NOT close.
            model = self.Model ;
            if isempty(model) || ~isvalid(model) ,
                shouldStayPut = false ;
            else
                shouldStayPut = ~model.isIdleSensuLato() ;
            end
        end
    end
    
    methods
        function exceptionMaybe = controlActuated(self, controlName, source, event, varargin)            
            % Gateway for all UI-initiated commands.
            try
                if isempty(source) ,
                    methodName=[controlName 'Actuated'] ;
                    if ismethod(self,methodName) ,
                        self.(methodName)(source,event,varargin{:}) ;
                    end
                else                    
                    type=get(source,'Type') ;
                    if isequal(type,'uitable') ,
                        if isfield(event,'EditData') || isprop(event,'EditData') ,
                            methodName=[controlName 'CellEdited'] ;
                        else
                            methodName=[controlName 'CellSelected'] ;
                        end
                        if ismethod(self,methodName) ,
                            self.(methodName)(source,event,varargin{:}) ;
                        end                    
                    elseif isequal(type,'uicontrol') || isequal(type,'uimenu') ,
                        methodName=[controlName 'Actuated'] ;
                        if ismethod(self,methodName) ,
                            self.(methodName)(source,event,varargin{:}) ;
                        end
                    end
                end
                exceptionMaybe = {} ;
            catch exception
                if isequal(exception.identifier,'ws:invalidPropertyValue') ,
                    exceptionMaybe = {} ;
                else
                    ws.raiseDialogOnException(exception) ;
                    exceptionMaybe = { exception } ;
                end
            end
        end
    end
    
    methods (Static=true)
        function setWithBenefits(object,propertyName,newValue)
            % Set a property, silently ignoring ws:invalidPropertyValue errors.
            % The model broadcasts Update on invalid values, which reverts the UI.
            try 
                object.(propertyName)=newValue;
            catch exception
                if ~isequal(exception.identifier,'ws:invalidPropertyValue') ,
                    rethrow(exception);
                end
            end
        end
        
        function monitorPositions = getMonitorPositions(~)
            % Get the monitor positions for the current monitor configuration.
            originalScreenUnits = get(0,'Units') ;
            set(0,'Units','pixels') ;
            monitorPositions = get(0,'MonitorPositions') ;
            set(0,'Units',originalScreenUnits) ;
        end
    end
    
    methods (Access=protected, Sealed = true)
        function extractAndDecodeLayoutFromMultipleWindowLayout_(self, multiWindowLayout, monitorPositions)
            if isscalar(multiWindowLayout) && isstruct(multiWindowLayout) ,
                layoutMaybe = ws.Controller.singleWindowLayoutMaybeFromMultiWindowLayout(multiWindowLayout, class(self)) ;
                if ~isempty(layoutMaybe) ,
                    layoutForThisClass = layoutMaybe{1} ;
                    self.decodeWindowLayout(layoutForThisClass, monitorPositions);
                end
            end
        end
    end
    
    methods (Static=true)
        function result = layoutVariableNameFromControllerClassName(controllerClassName)
            controllerClassNameWithoutPrefix = strrep(controllerClassName, 'ws.', '') ;
            figureClassName = strrep(controllerClassNameWithoutPrefix, 'Controller', 'Figure') ;
            if length(figureClassName)>63 ,
                result = figureClassName(1:63) ;
            else
                result = figureClassName ;
            end
        end
        
        function layoutMaybe = singleWindowLayoutMaybeFromMultiWindowLayout(multiWindowLayout, controllerClassName) 
            coreName = strrep(strrep(controllerClassName, 'ws.', ''), 'Controller', '') ;
            if isempty(multiWindowLayout) ,
                layoutMaybe = {} ;
            else
                multiWindowLayoutFieldNames = fieldnames(multiWindowLayout) ;
                layoutMaybe = {} ;
                for i = 1:length(multiWindowLayoutFieldNames) ,
                    fieldName = multiWindowLayoutFieldNames{i} ;
                    if contains(fieldName, coreName) ,
                        layoutMaybe = {multiWindowLayout.(fieldName)} ;
                        break
                    end
                end
            end
        end
    end
    
end
