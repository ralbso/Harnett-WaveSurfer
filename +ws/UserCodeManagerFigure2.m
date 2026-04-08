classdef UserCodeManagerFigure2 < ws.AppFigure
    % UserCodeManagerFigure2 — Modern uifigure-based User Code Manager window.
    % Replaces UserCodeManagerFigure + UserCodeManagerController.
    
    properties (Access = protected)
        EnabledCheckbox_
        ClassNameField_
        BrowseButton_
        ReinstantiateButton_
    end
    
    methods
        function self = UserCodeManagerFigure2(model)
            self@ws.AppFigure(model, 'User Code Manager', [420 120]) ;
            
            if ~isempty(model) && isvalid(model)
                model.subscribeMe(self, 'Update', '', 'update') ;
                model.subscribeMe(self, 'DidSetState', '', 'updateControlEnablement') ;
            end
            
            self.update() ;
            self.show() ;
        end
    end
    
    methods (Access = protected)
        function createComponents_(self)
            self.GridLayout_.RowHeight = {26, 26} ;
            self.GridLayout_.ColumnWidth = {100, '1x', 80, 100} ;
            self.GridLayout_.Padding = [10 10 10 10] ;
            self.GridLayout_.RowSpacing = 8 ;
            
            self.EnabledCheckbox_ = uicheckbox(self.GridLayout_, 'Text', 'Enabled', ...
                'ValueChangedFcn', @(~,~) self.enabledChanged_()) ;
            self.EnabledCheckbox_.Layout.Row = 1 ; self.EnabledCheckbox_.Layout.Column = 1 ;
            
            uilabel(self.GridLayout_, 'Text', 'Class Name:').Layout.Row = 2 ;
            self.ClassNameField_ = uieditfield(self.GridLayout_, ...
                'ValueChangedFcn', @(~,~) self.classNameChanged_()) ;
            self.ClassNameField_.Layout.Row = 2 ; self.ClassNameField_.Layout.Column = 2 ;
            
            self.BrowseButton_ = uibutton(self.GridLayout_, 'Text', 'Browse...', ...
                'ButtonPushedFcn', @(~,~) self.browsePushed_()) ;
            self.BrowseButton_.Layout.Row = 2 ; self.BrowseButton_.Layout.Column = 3 ;
            
            self.ReinstantiateButton_ = uibutton(self.GridLayout_, 'Text', 'Reinstantiate', ...
                'ButtonPushedFcn', @(~,~) self.reinstantiatePushed_()) ;
            self.ReinstantiateButton_.Layout.Row = 2 ; self.ReinstantiateButton_.Layout.Column = 4 ;
        end
        
        function updateControlPropertiesImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model)
                return
            end
            self.EnabledCheckbox_.Value = model.IsUserClassNameEnabled ;
            self.ClassNameField_.Value = model.TheUserClassName ;
        end
        
        function updateControlEnablementImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model)
                return
            end
            isIdle = isequal(model.State, 'idle') ;
            self.EnabledCheckbox_.Enable = ws.onIff(isIdle) ;
            self.ClassNameField_.Enable = ws.onIff(isIdle) ;
            self.BrowseButton_.Enable = ws.onIff(isIdle) ;
            self.ReinstantiateButton_.Enable = ws.onIff(isIdle) ;
        end
        
        function enabledChanged_(self)
            try self.Model_.do('set', 'IsUserClassNameEnabled', self.EnabledCheckbox_.Value) ;
            catch me, ws.raiseDialogOnException(me) ; end
        end
        
        function classNameChanged_(self)
            try self.Model_.do('set', 'TheUserClassName', self.ClassNameField_.Value) ;
            catch me, ws.raiseDialogOnException(me) ; end
        end
        
        function browsePushed_(self)
            [fileName, pathName] = uigetfile({'*.m', 'MATLAB Files'}, 'Select User Class') ;
            if ~isequal(fileName, 0)
                [~, className] = fileparts(fileName) ;
                try self.Model_.do('set', 'TheUserClassName', className) ;
                catch me, ws.raiseDialogOnException(me) ; end
            end
        end
        
        function reinstantiatePushed_(self)
            try self.Model_.do('reinstantiateUserObject') ;
            catch me, ws.raiseDialogOnException(me) ; end
        end
        
        function closeRequested_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model) || model.isIdleSensuLato()
                self.hide() ;
            end
        end
    end
    
end
