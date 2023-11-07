//
//  WidgetCollectionView.swift
//  tomato
//
//  Created by Kevin on 2023/11/6.
//

import Foundation
import UIKit

public protocol WidgetCollectionViewDataSource: NSObjectProtocol {
    
    func numberOfItems() -> Int
    func sizeOfItem(at index: Int) -> CGSize
    func collectionView(_ collectionView: WidgetCollectionView, cellForItemAt index: Int) -> WidgetCollectionCell?
    
}

public protocol WidgetCollectionViewDelegate: UIScrollViewDelegate {
    
    func collectionView(_ collectionView: WidgetCollectionView, didSelectItemAt index: Int)
    
}

open class WidgetCollectionView: UIScrollView, UIScrollViewDelegate {
    
    private var allScreens: [WidgetCollectionCell] = [],
                outOfScreens: [String: WidgetCollectionCell] = [:],
                onScreens: [String: WidgetCollectionCell] = [:],
                registers: [String: WidgetCollectionCell.Type?] = [:],
                minX: CGFloat = 0,
                minY: CGFloat = 0,
                maxY: CGFloat = 0,
                enableSelected: Bool = true
    
    public var spacing: CGFloat = 0
    
    public weak var dataSource: WidgetCollectionViewDataSource?
    private weak var widgetDelegate: WidgetCollectionViewDelegate?
    public override var delegate: UIScrollViewDelegate? {
        didSet {
            if let d = delegate as? WidgetCollectionViewDelegate {
                widgetDelegate = d
                delegate = self
            }
        }
    }
    
    public func reloadData() {
        DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
            self.layoutAllCell()
        }
    }
    
    private func layoutAllCell() {
        let width = bounds.width,
            count = dataSource?.numberOfItems() ?? 0
        self.allScreens.removeAll()
        for i in 0..<count {
            if let cell = dataSource?.collectionView(self, cellForItemAt: i), let size = dataSource?.sizeOfItem(at: i) {
                var cellFrame = CGRect(origin: .zero, size: size)
                if minX+size.width > width {
                    cellFrame.origin = CGPoint(x: 0, y: maxY)
                    minX = cellFrame.maxX+spacing
                    minY = cellFrame.minY
                }else {
                    cellFrame.origin = CGPoint(x: minX, y: minY)
                    if cellFrame.maxX+spacing <= width {
                        minX = cellFrame.maxX+spacing
                    }else {
                        self.minY = cellFrame.maxY+spacing
                    }
                }
                if cellFrame.maxY+spacing > maxY {
                    maxY = cellFrame.maxY+spacing
                }
                if minY >= self.maxY {
                    minX = 0
                }
                cell.frame = cellFrame
                allScreens.append(cell)
            }
        }
        contentSize = CGSize(width: width, height: maxY)
        scrollViewDidScroll(self)
    }
    
    public func dequeueReusableView(withReuseIdentifier identifier: String, for index: Int) -> WidgetCollectionCell? {
        var cell: WidgetCollectionCell?
        let reuseIdentifier = "\(identifier)_\(index)"
        if let reuseCell = outOfScreens[reuseIdentifier] {
            cell = reuseCell
        }
        if let viewClass = registers[identifier] as? WidgetCollectionCell.Type {
            cell = viewClass.init(reuseIdentifier: identifier, index: index)
        }
        if let _ = cell {
            onScreens[reuseIdentifier] = cell
            outOfScreens.removeValue(forKey: reuseIdentifier)
        }
        return cell
    }
    
    public func register(_ viewClass: WidgetCollectionCell.Type?, forViewWithReuseIdentifier identifier: String) {
        registers[identifier] = viewClass
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var screenFrame = scrollView.bounds
        screenFrame.origin = scrollView.contentOffset
        allScreens.forEach { v in
            let reuseIdentifier = "\(String(describing: v.reuseIdentifier))_\(v.index)"
            if CGRectIntersectsRect(v.frame, screenFrame) {
                onScreens[reuseIdentifier] = v
                outOfScreens.removeValue(forKey: reuseIdentifier)
                addSubview(v)
            }else {
                onScreens.removeValue(forKey: reuseIdentifier)
                outOfScreens[reuseIdentifier] = v
                v.removeFromSuperview()
            }
        }
        widgetDelegate?.scrollViewDidScroll?(scrollView)
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        widgetDelegate?.scrollViewDidZoom?(scrollView)
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        widgetDelegate?.scrollViewWillBeginDragging?(scrollView)
    }
    
    public func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        widgetDelegate?.scrollViewWillBeginDecelerating?(scrollView)
    }
    
    public func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        widgetDelegate?.scrollViewWillBeginZooming?(scrollView, with: view)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        widgetDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
    }
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        widgetDelegate?.scrollViewWillEndDragging?(scrollView, withVelocity: velocity, targetContentOffset: targetContentOffset)
    }
    
    public func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        widgetDelegate?.scrollViewDidScrollToTop?(scrollView)
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        widgetDelegate?.scrollViewDidEndDecelerating?(scrollView)
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        widgetDelegate?.scrollViewDidEndScrollingAnimation?(scrollView)
    }
    
    public func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView) {
        widgetDelegate?.scrollViewDidChangeAdjustedContentInset?(scrollView)
    }
    
    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        widgetDelegate?.scrollViewDidEndZooming?(scrollView, with: view, atScale: scale)
    }
    
    public func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        return widgetDelegate?.scrollViewShouldScrollToTop?(scrollView) ?? true
    }
    
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return widgetDelegate?.viewForZooming?(in: scrollView)
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for view in subviews {
            if view.frame.contains(point), let cell = view as? WidgetCollectionCell {
                if enableSelected {
                    enableSelected = false
                    widgetDelegate?.collectionView(self, didSelectItemAt: cell.index)
                    DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
                        self.enableSelected = true
                    }
                }
                return view
            }
        }
        return self
    }
    
}

open class WidgetCollectionCell: UIView {
    
    open var reuseIdentifier: String?,
        index: Int = 0
    
    public required convenience init(reuseIdentifier: String?, index: Int) {
        self.init()
        self.reuseIdentifier = reuseIdentifier
        self.index = index
        self.setUpView()
    }
    
    open func setUpView() {
        
    }
    
}
