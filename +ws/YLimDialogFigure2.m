classdef YLimDialogFigure2 < handle
    % YLimDialogFigure2 — Modern modal dialog for setting Y axis limits.
    % Replaces YLimDialogFigure (MCOSFigureWithSelfControl).
    % This is a standalone dialog, not an AppFigure subclass, because it's modal.
    
    properties (Access = protected)
        Figure_
        YMaxField_
        YMinField_
        OKButton_
        CancelButton_
        YUnits_
        CallbackFunction_
    end
    
    methods
        function self = YLimDialogFigure2(parentFigure, yLimits, yUnits, callbackFunction)
            self.YUnits_ = yUnits ;
            self.CallbackFunction_ = callbackFunction ;
            
            self.Figure_ = uifigure('Name', 'Y Limits...', ...
                'Position', [200 200 220 130], ...
                'Resize', 'off', ...
                'WindowStyle', 'modal', ...
                'CloseRequestFcn', @(~,~) self.cancel_()) ;
            
            % Center on parent
            if ~isempty(parentFigure) && isvalid(parentFigure)
                parentPos = parentFigure.Position ;
                figSize = self.Figure_.Position(3:4) ;
                newOffset = parentPos(1:2) + (parentPos(3:4) - figSize) / 2 ;
                self.Figure_.Position = [newOffset figSize] ;
            end
            
            g = uigridlayout(self.Figure_, ...
                'RowHeight', {28, 28, 10, 28}, ...
                'ColumnWidth', {60, '1x', 40}, ...
                'Padding', [10 10 10 10], 'RowSpacing', 4) ;
            
            uilabel(g, 'Text', 'Y Max:', 'HorizontalAlignment', 'right') ;
            self.YMaxField_ = uieditfield(g, 'numeric', 'Value', yLimits(2)) ;
            self.YMaxField_.Layout.Column = 2 ;
            uilabel(g, 'Text', yUnits).Layout.Column = 3 ;
            
            uilabel(g, 'Text', 'Y Min:', 'HorizontalAlignment', 'right').Layout.Row = 2 ;
            self.YMinField_ = uieditfield(g, 'numeric', 'Value', yLimits(1)) ;
            self.YMinField_.Layout.Row = 2 ; self.YMinField_.Layout.Column = 2 ;
            uilabel(g, 'Text', yUnits).Layout.Row = 2 ;
            
            % Button row
            buttonGrid = uigridlayout(g, ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {'1x', 60, 6, 60}, ...
                'Padding', [0 0 0 0]) ;
            buttonGrid.Layout.Row = 4 ; buttonGrid.Layout.Column = [1 3] ;
            
            self.OKButton_ = uibutton(buttonGrid, 'Text', 'OK', ...
                'ButtonPushedFcn', @(~,~) self.ok_()) ;
            self.OKButton_.Layout.Column = 2 ;
            
            self.CancelButton_ = uibutton(buttonGrid, 'Text', 'Cancel', ...
                'ButtonPushedFcn', @(~,~) self.cancel_()) ;
            self.CancelButton_.Layout.Column = 4 ;
            
            % Focus the max field
            focus(self.YMaxField_) ;
        end
        
        function delete(self)
            if ~isempty(self.Figure_) && isvalid(self.Figure_)
                delete(self.Figure_) ;
            end
        end
    end
    
    methods (Access = protected)
        function ok_(self)
            yMax = self.YMaxField_.Value ;
            yMin = self.YMinField_.Value ;
            if isfinite(yMax) && isfinite(yMin) && yMin ~= yMax
                if yMin > yMax
                    temp = yMax ; yMax = yMin ; yMin = temp ;
                end
                feval(self.CallbackFunction_, [yMin yMax]) ;
            end
            self.cancel_() ;  % close the dialog
        end
        
        function cancel_(self)
            if ~isempty(self.Figure_) && isvalid(self.Figure_)
                delete(self.Figure_) ;
            end
            self.Figure_ = [] ;
        end
    end
end
