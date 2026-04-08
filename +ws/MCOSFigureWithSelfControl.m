classdef (Abstract) MCOSFigureWithSelfControl < ws.EventSubscriber
    % Base class that wraps a handle graphics figure in a proper MCOS object,
    % with no separate controller. All UI action methods are in the subclass.
    
    properties (Access=protected, Transient=true)
        DegreeOfEnablement_ = 1
        NCallsToUpdateWhileDisabled_ = []    
        NCallsToUpdateControlPropertiesWhileDisabled_ = []    
        NCallsToUpdateControlEnablementWhileDisabled_ = []    
    end
    
    properties (Dependent=true, Transient=true)
        AreUpdatesEnabled
    end

    properties (Access=protected)
        FigureGH_
        Model_
    end
    
    methods
        function self = MCOSFigureWithSelfControl(model)
            backgroundColor = ws.getDefaultUIControlBackgroundColor() ;
            self.FigureGH_=figure('Units','Pixels', ...
                                  'Color',backgroundColor, ...
                                  'Visible','off', ...
                                  'HandleVisibility','off', ...
                                  'DockControls','off', ...
                                  'CloseRequestFcn',@(source,event)(self.closeRequested_(source,event))) ;
            if exist('model','var') ,
                self.Model_ = model ;
                if ~isempty(model) && isvalid(model) ,
                    model.subscribeMe(self,'UpdateReadiness','','updateReadiness');
                end
            else
                self.Model_ = [] ;
            end
        end
        
        function delete(self)
            self.deleteFigureGH_();
            self.Model_ = [] ;
        end
        
        function set.AreUpdatesEnabled(self,newValue)
            if ~( islogical(newValue) && isscalar(newValue) ) ,
                return
            end
            
            netValueBefore=self.AreUpdatesEnabled;
            
            newValueAsSign=2*double(newValue)-1;
            newDegreeOfEnablementRaw=self.DegreeOfEnablement_+newValueAsSign;
            self.DegreeOfEnablement_ = ...
                    ws.fif(newDegreeOfEnablementRaw<=1, ...
                           newDegreeOfEnablementRaw, ...
                           1);
            
            netValueAfter=self.AreUpdatesEnabled;
            
            if netValueAfter && ~netValueBefore ,
                if self.NCallsToUpdateWhileDisabled_>0
                    self.updateImplementation_();
                elseif self.NCallsToUpdateControlPropertiesWhileDisabled_>0
                    self.updateControlPropertiesImplementation_();
                elseif self.NCallsToUpdateControlEnablementWhileDisabled_>0
                    self.updateControlEnablementImplementation_();
                end
                self.NCallsToUpdateWhileDisabled_=[];
                self.NCallsToUpdateControlPropertiesWhileDisabled_=[];
                self.NCallsToUpdateControlEnablementWhileDisabled_=[];
            elseif ~netValueAfter && netValueBefore ,
                self.NCallsToUpdateWhileDisabled_=0;
                self.NCallsToUpdateControlPropertiesWhileDisabled_=0;
                self.NCallsToUpdateControlEnablementWhileDisabled_=0;
            end            
        end

        function value=get.AreUpdatesEnabled(self)
            value=(self.DegreeOfEnablement_>0);
        end
        
        function update(self, varargin)
            self.update_(varargin{:}) ;
        end
        
        function updateControlProperties(self, varargin)
            self.updateControlProperties_(varargin{:}) ;
        end

        function updateControlEnablement(self, varargin)
            self.updateControlEnablement_(varargin{:}) ;
        end
        
        function updateReadiness(self, varargin)
            self.updateReadiness_(varargin{:}) ;
        end
        
        function decodeWindowLayout(self, layoutOfWindowsInClass, monitorPositions)
            fieldNames = fieldnames(layoutOfWindowsInClass) ;
            if isscalar(fieldNames) ,
                fieldName = fieldNames{1} ;
                layoutOfThisWindow = layoutOfWindowsInClass.(fieldName) ;
                isVisibleFieldName = 'Visible' ;
            else
                layoutOfThisWindow = layoutOfWindowsInClass ;
                isVisibleFieldName = 'IsVisible' ;
            end
            if isfield(layoutOfThisWindow, 'Position') ,
                rawPosition = layoutOfThisWindow.Position ;
                set(self, 'Position', rawPosition);
                self.constrainPositionToMonitors(monitorPositions) ;
            end
            if isfield(layoutOfThisWindow, isVisibleFieldName) ,
                set(self, 'Visible', layoutOfThisWindow.(isVisibleFieldName)) ;
            end
        end        
    end

    methods (Access=protected)
        function set(self,propName,value)
            if strcmpi(propName,'Visible') && islogical(value) && isscalar(value) ,
                if value,
                    set(self.FigureGH_,'Visible','on');
                else
                    set(self.FigureGH_,'Visible','off');
                end
            else
                set(self.FigureGH_,propName,value);
            end
        end
        
        function value=get(self,propName)
            value=get(self.FigureGH_,propName);
        end
        
        function update_(self,varargin)
            if self.AreUpdatesEnabled ,
                self.updateImplementation_();
            else
                self.NCallsToUpdateWhileDisabled_=self.NCallsToUpdateWhileDisabled_+1;
            end
        end
        
        function updateControlProperties_(self,varargin)
            if self.AreUpdatesEnabled ,
                self.updateControlPropertiesImplementation_();
            else
                self.NCallsToUpdateControlPropertiesWhileDisabled_=self.NCallsToUpdateControlPropertiesWhileDisabled_+1;
            end
        end
        
        function updateControlEnablement_(self,varargin)
            if self.AreUpdatesEnabled ,
                self.updateControlEnablementImplementation_();
            else
                self.NCallsToUpdateControlEnablementWhileDisabled_=self.NCallsToUpdateControlEnablementWhileDisabled_+1;
            end            
        end
        
        function updateReadiness_(self,varargin)
            self.updateReadinessImplementation_();
        end

        function doWithModel_(self, varargin)
            if ~isempty(self.Model_) ,
                self.Model_.do(varargin{:}) ;
            end
        end
        
        function positionUpperLeftRelativeToOtherUpperRight_(self, referenceFigurePosition, offset)
            figureGH = self.FigureGH_ ;
            originalUnits=get(figureGH,'units');
            set(figureGH,'units','pixels');
            position=get(figureGH,'position');
            set(figureGH,'units',originalUnits);
            figureSize=position(3:4);

            referenceFigureOffset=referenceFigurePosition(1:2);
            referenceFigureSize=referenceFigurePosition(3:4);

            origin = referenceFigureOffset + referenceFigureSize ;
            figureHeight=figureSize(2);
            newOffset = [ origin(1) + offset(1) ...
                          origin(2) + offset(2) - figureHeight ] ;

            originalUnits=get(figureGH,'units');
            set(figureGH,'units','pixels');
            set(figureGH,'position',[newOffset figureSize]);
            set(figureGH,'units',originalUnits);            
        end
        
        createFixedControls_(self)
        
        function updateControlsInExistance_(self)  %#ok<MANU>
        end
        
        updateControlPropertiesImplementation_(self) 
        updateControlEnablementImplementation_(self) 
        figureSize=layoutFixedControls_(self) 
        
        function figureSizeModified=layoutNonfixedControls_(self,figureSize)  %#ok<INUSL>
            figureSizeModified=figureSize;
        end
        
        function layout_(self)
            figureSize=self.layoutFixedControls_();
            figureSizeModified=self.layoutNonfixedControls_(figureSize);
            ws.resizeLeavingUpperLeftFixedBang(self.FigureGH_,figureSizeModified);            
        end
        
        function updateImplementation_(self)
            self.updateControlsInExistance_();
            self.updateControlPropertiesImplementation_();
            self.updateControlEnablementImplementation_();
            self.layout_();
        end
        
        function updateReadinessImplementation_(self)
            if isempty(self.Model_) 
                pointerValue = 'arrow';
            elseif isvalid(self.Model_)
                if self.Model_.IsReady ,
                    pointerValue = 'arrow';
                else
                    pointerValue = 'watch';
                end
            else
                pointerValue = 'arrow';
            end
            set(self.FigureGH_,'pointer',pointerValue);
            drawnow('update');
        end
    end
    
    methods (Access=protected)
        function setIsVisible_(self, newValue)
            if ~isempty(self.FigureGH_) && ishghandle(self.FigureGH_) ,
                set(self.FigureGH_, 'Visible', ws.onIff(newValue));
            end
        end
    end
    
    methods
        function show(self)
            self.setIsVisible_(true);
        end

        function hide(self)
            self.setIsVisible_(false);
        end
    
        function raise(self)
            self.hide() ;
            self.show() ;  
        end
    end
    
    methods (Access=protected)
        function closeRequested_(self, source, event)  %#ok<INUSD>
            self.deleteFigureGH_();
        end
    end
            
    methods (Access=protected)
        function deleteFigureGH_(self)   
            if ~isempty(self.FigureGH_) && ishghandle(self.FigureGH_) ,
                delete(self.FigureGH_);
            end
            self.FigureGH_ = [] ;
        end
    end
        
    methods
        function exceptionMaybe = controlActuated(self, methodNameStem, source, event, varargin)
            try
                if isempty(source) ,
                    methodName=[methodNameStem 'Actuated'] ;
                    if ismethod(self,methodName) ,
                        self.(methodName)(source, event, varargin{:});
                    end
                else
                    type=get(source,'Type');
                    if isequal(type,'uitable') ,
                        if isfield(event,'EditData') || isprop(event,'EditData') ,
                            methodName=[methodNameStem 'CellEdited'];
                        else
                            methodName=[methodNameStem 'CellSelected'];
                        end
                        if ismethod(self,methodName) ,
                            self.(methodName)(source, event, varargin{:});
                        end
                    elseif isequal(type,'uicontrol') || isequal(type,'uimenu') ,
                        methodName=[methodNameStem 'Actuated'] ;
                        if ismethod(self,methodName) ,
                            self.(methodName)(source, event, varargin{:});
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
    
    methods
        function constrainPositionToMonitors(self, monitorPositions)
            figureOuterPosition = get(self.FigureGH_, 'OuterPosition') ;
            figurePosition = get(self.FigureGH_, 'Position') ;
            
            function translation = translationToFit2D(offset, sz, screenOffset, screenSize)
                xTranslation = translationToFit1D(offset(1), sz(1), screenOffset(1), screenSize(1)) ;
                yTranslation = translationToFit1D(offset(2), sz(2), screenOffset(2), screenSize(2)) ;
                translation = [xTranslation yTranslation] ;
            end

            function translation = translationToFit1D(offset, sz, screenOffset, screenSize)
                topOffset = offset + sz ;
                screenTop = screenOffset+screenSize ;
                if offset < screenOffset ,
                    translation = screenOffset - offset ;
                elseif topOffset > screenTop ,
                    translation = (screenTop - sz) - offset ;
                else
                    translation = 0 ;
                end
            end
            
            figureOuterOffset = figureOuterPosition(1:2) ;
            figureOuterSize = figureOuterPosition(3:4) ;
            figureOffset = figurePosition(1:2) ;
            figureSize = figurePosition(3:4) ;
            
            nMonitors = size(monitorPositions, 1) ;
            figureTranslationForEachMonitor = zeros(nMonitors,2) ;
            for i = 1:nMonitors ,
                monitorPosition = monitorPositions(i,:) ;
                figureTranslationForEachMonitor(i,:) = translationToFit2D(figureOuterOffset, figureOuterSize, monitorPosition(1:2), monitorPosition(3:4)) ;
            end

            sizeOfFigureTranslationForEachMonitor = hypot(figureTranslationForEachMonitor(:,1), figureTranslationForEachMonitor(:,2)) ;
            [~,idx] = min(sizeOfFigureTranslationForEachMonitor) ;
            if isempty(idx) ,
                figureTranslation = [0 0] ;
            else
                figureTranslation = figureTranslationForEachMonitor(idx,:) ;
            end        

            set(self.FigureGH_, 'Position', [figureOffset+figureTranslation figureSize]) ;
        end
    end
    
    methods (Sealed = true)
        function layoutForAllWindows = addThisWindowLayoutToLayout(self, layoutForAllWindows)
            thisWindowLayout = self.encodeWindowLayout_();
            layoutVarNameForClass = ws.Controller.layoutVariableNameFromControllerClassName(class(self));
            layoutForAllWindows.(layoutVarNameForClass)=thisWindowLayout;
        end
    end
    
    methods (Access = protected)
        function layout = encodeWindowLayout_(self)
            fig = self.FigureGH_ ;
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
    
    methods
        function setAreUpdatesEnabledForFigure(self,newValue)
            self.AreUpdatesEnabled = newValue ;
        end        
    end

end
