classdef (Abstract) MCOSFigure < ws.EventSubscriber
    % Base class that wraps a handle graphics figure in a proper MCOS object.
    
    properties (Access=protected, Transient=true)
        DegreeOfEnablement_ = 1
            % Supports nested disable/enable: an integer always <= 1.
            % Positive means enabled, zero or negative means disabled.
        NCallsToUpdateWhileDisabled_ = []    
        NCallsToUpdateControlPropertiesWhileDisabled_ = []    
        NCallsToUpdateControlEnablementWhileDisabled_ = []    
    end
    
    properties (Dependent=true, Transient=true)
        AreUpdatesEnabled   % logical scalar; if false, changes in the model should not be reflected in the UI
    end
    
    properties (Dependent=true, SetAccess=immutable)
        FigureGH  % the figure graphics handle
        Controller  % the controller, an instance of ws.Controller
        Model  % the model        
    end

    properties (Access=protected)
        FigureGH_
        Controller_
        Model_
    end
    
    methods
        function self=MCOSFigure(model, controller)
            backgroundColor = ws.getDefaultUIControlBackgroundColor() ;
            self.FigureGH_=figure('Units','Pixels', ...
                                  'Color',backgroundColor, ...
                                  'Visible','off', ...
                                  'HandleVisibility','off', ...
                                  'DockControls','off', ...
                                  'CloseRequestFcn',@(source,event)(self.closeRequested(source,event)));
            if exist('model','var')
                self.setModel_(model);
            else
                self.setModel_([]);
            end
            if exist('controller','var')
                self.Controller_=controller;
            else
                self.Controller_=[];
            end
        end
        
        function delete(self)
            self.deleteFigureGH_() ;
            self.Controller_=[];
            self.Model_ = [] ;
        end
        
        function output = get.Model(self)
            output = self.Model_ ;
        end
        
        function output = get.FigureGH(self)
            output = self.FigureGH_ ;
        end
        
        function output = get.Controller(self)
            output = self.Controller_ ;
        end
                
        function setModel_(self, newValue)
            self.willSetModel_();
            self.Model_ = newValue ;            
            self.didSetModel_();
        end
        
        function set.AreUpdatesEnabled(self,newValue)
            if ~( islogical(newValue) && isscalar(newValue) ) ,
                return
            end
            
            netValueBefore=self.AreUpdatesEnabled;
            
            newValueAsSign=2*double(newValue)-1;  % [0,1] -> [-1,+1]
            newDegreeOfEnablementRaw=self.DegreeOfEnablement_+newValueAsSign;
            self.DegreeOfEnablement_ = ...
                    ws.fif(newDegreeOfEnablementRaw<=1, ...
                           newDegreeOfEnablementRaw, ...
                           1);
            
            netValueAfter=self.AreUpdatesEnabled;
            
            if netValueAfter && ~netValueBefore ,
                % Updates have just been enabled — flush deferred updates
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
                % Updates have just been disabled
                self.NCallsToUpdateWhileDisabled_=0;
                self.NCallsToUpdateControlPropertiesWhileDisabled_=0;
                self.NCallsToUpdateControlEnablementWhileDisabled_=0;
            end            
        end

        function value=get.AreUpdatesEnabled(self)
            value=(self.DegreeOfEnablement_>0);
        end
        
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
        
        function update(self,varargin)
            % Full re-sync figure with model.
            if self.AreUpdatesEnabled ,
                self.updateImplementation_();
            else
                self.NCallsToUpdateWhileDisabled_=self.NCallsToUpdateWhileDisabled_+1;
            end
        end
        
        function updateControlProperties(self,varargin)
            % Re-sync control properties (not enablement, not layout).
            if self.AreUpdatesEnabled ,
                self.updateControlPropertiesImplementation_();
            else
                self.NCallsToUpdateControlPropertiesWhileDisabled_=self.NCallsToUpdateControlPropertiesWhileDisabled_+1;
            end
        end
        
        function updateControlEnablement(self,varargin)
            % Re-sync Enable property of each control.
            if self.AreUpdatesEnabled ,
                self.updateControlEnablementImplementation_();
            else
                self.NCallsToUpdateControlEnablementWhileDisabled_=self.NCallsToUpdateControlEnablementWhileDisabled_+1;
            end            
        end
        
        function updateReadiness(self, varargin)
            self.updateReadinessImplementation_() ;
        end

        function positionUpperLeftRelativeToOtherUpperRight(self, other, offset)
            ws.positionFigureUpperLeftRelativeToFigureUpperRightBang(self.FigureGH_, other.FigureGH, offset) ;
        end
    end  % public methods

    methods (Access=protected)
        createFixedControls_(self)
            % Subclass: create all controls that persist for the figure lifetime.
        
        function updateControlsInExistance_(self)  %#ok<MANU>
            % Subclass: sync non-fixed controls with model state.
            % Default does nothing (appropriate if all controls are fixed).
        end
        
        updateControlPropertiesImplementation_(self) 
            % Subclass: sync control properties (except Position/Enable) with model.
        
        updateControlEnablementImplementation_(self) 
            % Subclass: sync Enable property of each control with model.
        
        figureSize=layoutFixedControls_(self) 
            % Subclass: position all fixed controls.
        
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
            % Hide then show — works well for bringing figures to front
            self.hide() ;
            self.show() ;  
        end
    end
    
    methods (Access = protected)
        function updateGuidata_(self)
            handles=ws.MCOSFigure.updateGuidataHelper_(struct(),self.FigureGH_);
            handles.FigureObject=self;
            guidata(self.FigureGH_,handles);
        end
    end
    
    methods (Access=protected)
        function willSetModel_(self)
            self.unsubscribeFromAll();
        end
        
        function didSetModel_(self) 
            model=self.Model_;
            if ~isempty(model) && isvalid(model) ,
                model.subscribeMe(self,'UpdateReadiness','','updateReadiness');
            end
        end
    end   
    
    methods (Static=true)
        function handles=updateGuidataHelper_(handles,containerGH)
            % Recursively builds a struct of Tag->handle mappings for all controls.
            childControlGHs=get(containerGH,'Children');
            nChildren=length(childControlGHs);
            for i=1:nChildren ,
                childControlGH=childControlGHs(i);
                tag=get(childControlGH,'Tag');
                handles.(tag)=childControlGH;
                if isequal(get(childControlGH,'Type'),'uipanel') ,
                    handles=ws.MCOSFigure.updateGuidataHelper_(handles,childControlGH);
                end
            end
            tag=get(containerGH,'Tag');
            handles.(tag)=containerGH;
        end
    end
    
    methods (Access = protected)
        function setHGTagsToPropertyNames_(self)
            mc=metaclass(self);
            propertyNames={mc.PropertyList.Name};
            for i=1:length(propertyNames) ,
                propertyName=propertyNames{i};
                propertyThing=self.(propertyName);
                if ~isempty(propertyThing) && all(ishghandle(propertyThing)) && ~(isscalar(propertyThing) && isequal(get(propertyThing,'Type'),'figure')) ,
                    set(propertyThing,'Tag',propertyName);                    
                end
            end
        end
    end
    
    methods
        function closeRequested(self,source,event)            
            if isempty(self.Controller_) ,
                delete(self) ;
            else
                self.Controller_.windowCloseRequested(source,event);
            end
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
        function controlActuated(self,controlName,source,event,varargin)
            if isempty(self.Controller_) || ~isvalid(self.Controller_) ,
                % do nothing
            else
                self.Controller_.controlActuated(controlName,source,event,varargin{:});
            end
        end
    end
    
    methods
        function position = getPositionInPixels(self)
            figureGH = self.FigureGH_ ;
            originalUnits=get(figureGH,'units');
            set(figureGH,'units','pixels');
            position = get(figureGH,'position') ;
            set(figureGH,'units',originalUnits);            
        end
        
        function constrainPositionToMonitors(self, monitorPositions)
            figureOuterPosition = get(self.FigureGH, 'OuterPosition') ;
            figurePosition = get(self.FigureGH, 'Position') ;
            
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
                monitorOffset = monitorPosition(1:2) ;
                monitorSize = monitorPosition(3:4) ;
                figureTranslationForEachMonitor(i,:) = translationToFit2D(figureOuterOffset, figureOuterSize, monitorOffset, monitorSize) ;
            end

            sizeOfFigureTranslationForEachMonitor = hypot(figureTranslationForEachMonitor(:,1), figureTranslationForEachMonitor(:,2)) ;
            [~,indexOfSmallestFigureTranslation] = min(sizeOfFigureTranslationForEachMonitor) ;
            if isempty(indexOfSmallestFigureTranslation) ,
                figureTranslation = [0 0] ;
            else
                figureTranslation = figureTranslationForEachMonitor(indexOfSmallestFigureTranslation,:) ;
            end        

            newFigurePosition = [figureOffset+figureTranslation figureSize] ;
            set(self.FigureGH, 'Position', newFigurePosition) ;
        end
    end
    
end
