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

@objc public protocol WidgetCollectionViewDelegate: UIScrollViewDelegate {
    
    func collectionView(_ collectionView: WidgetCollectionView, didSelectItemAt index: Int)
    @objc optional func collectionView(_ collectionView: WidgetCollectionView, didDeleteItemAt index: Int)
    @objc optional func collectionView(_ collectionView: WidgetCollectionView, canDeleteItemAt index: Int) -> Bool
    @objc optional func collectionView(_ collectionView: WidgetCollectionView, exchangeItemAt index: Int, toIndex: Int)
    
}

protocol WidgetCollectionCellDelegate: NSObjectProtocol {
    
    func didTouchDelete(_ cell: WidgetCollectionCell, didDeleteItemAt index: Int)
    func didTouch(_ cell: WidgetCollectionCell, didSelectItemAt index: Int)
    
}

open class WidgetCollectionView: UIScrollView, UIScrollViewDelegate, WidgetCollectionCellDelegate {
    
    private var allScreens: [WidgetCollectionCell] = [],
                outOfScreens: [String: WidgetCollectionCell] = [:],
                onScreens: [String: WidgetCollectionCell] = [:],
                registers: [String: WidgetCollectionCell.Type?] = [:],
                minX: CGFloat = 0,
                minY: CGFloat = 0,
                maxY: CGFloat = 0,
                enableSelected: Bool = true,
                inShake: Bool = false,
                lastCenter: CGPoint = .zero,
                comparePoint: CGPoint = .zero,
                lastCell: WidgetCollectionCell?
    
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
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(widgetLongGesture(_:)))
        addGestureRecognizer(longPress)
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
            cell?.delegate = self
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
        stopShake()
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
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        stopShake()
    }
    
    @objc private func widgetLongGesture(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            if inShake || lastCell != nil {
                return
            }
            let point = sender.location(in: sender.view)
            for view in allScreens {
                if view.frame.contains(point), let shake = widgetDelegate?.collectionView?(self, canDeleteItemAt: view.index), shake {
                    bringSubviewToFront(view)
                    let p = sender.location(in: view)
                    comparePoint = CGPoint(x: p.x-view.bounds.midX, y: p.y-view.bounds.midY)
                    view.startShake()
                    lastCell = view
                    lastCenter = view.center
                    return
                }
            }
            inShake = true
            onScreens.forEach { key, value in
                if let shake = widgetDelegate?.collectionView?(self, canDeleteItemAt: value.index), shake {
                    value.deleteBtn.isHidden = false
                    value.startShake()
                }
            }
        case .changed:
            if let cell = lastCell {
                let point = sender.location(in: sender.view)
                cell.center = CGPoint(x: point.x-comparePoint.x, y: point.y-comparePoint.y)
                var inOther = false
                for view in allScreens {
                    if view.index != cell.index, view.frame.contains(cell.center), let shake = widgetDelegate?.collectionView?(self, canDeleteItemAt: view.index), shake {
                        inOther = true
                        break
                    }
                }
                if inOther {
                    cell.contentView.layer.shadowColor = UIColor.green.cgColor
                    cell.contentView.layer.shadowOpacity = 0.5
                }else {
                    cell.contentView.layer.shadowColor = UIColor.red.cgColor
                    cell.contentView.layer.shadowOpacity = 0.2
                }
            }
        case .ended:
            if let cell = lastCell {
                cell.contentView.layer.shadowOpacity = 0
                for view in allScreens {
                    if view.index != cell.index, view.frame.contains(cell.center) {
                        widgetDelegate?.collectionView?(self, exchangeItemAt: cell.index, toIndex: view.index)
                        break
                    }
                }
                UIView.animate(withDuration: 0.25) {
                    cell.stopShake()
                    cell.center = self.lastCenter
                } completion: { finished in
                    self.lastCell = nil
                }

            }
        default:
            break
        }
    }
    
    private func stopShake() {
        if inShake {
            inShake = false
            allScreens.forEach { value in
                value.stopShake()
                value.deleteBtn.isHidden = true
            }
        }
    }
    
    func didTouchDelete(_ cell: WidgetCollectionCell, didDeleteItemAt index: Int) {
        widgetDelegate?.collectionView?(self, didDeleteItemAt: index)
    }
    
    func didTouch(_ cell: WidgetCollectionCell, didSelectItemAt index: Int) {
        widgetDelegate?.collectionView(self, didSelectItemAt: index)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

open class WidgetCollectionCell: UIView {
    
    weak var delegate: WidgetCollectionCellDelegate?
    
    public var reuseIdentifier: String?,
               index: Int = 0
    
    public lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.shadowOffset = .zero
        view.layer.shadowRadius = 10
        return view
    }()
    lazy var deleteBtn: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(UIImage(systemName: "minus.circle"), for: .normal)
        button.isHidden = true
        button.tintColor = .red
        button.addTarget(self, action: #selector(touchDelete), for: .touchUpInside)
        return button
    }()
    lazy var rotationAni: CABasicAnimation = {
        let value = 50/180/Double.pi
        let animation = CABasicAnimation(keyPath: "transform.rotation")
        animation.duration = 0.15
        animation.repeatCount = .infinity
        animation.autoreverses = true
        animation.fromValue = -value
        animation.toValue = value
        animation.isRemovedOnCompletion = false
        return animation
    }()
    
    public override var frame: CGRect {
        didSet {
            contentView.frame = bounds
            deleteBtn.frame = CGRect(x: bounds.maxX-30, y: bounds.minY, width: 30, height: 30)
        }
    }
    
    public required convenience init(reuseIdentifier: String?, index: Int) {
        self.init()
        self.reuseIdentifier = reuseIdentifier
        self.index = index
        self.setUpView()
    }
    
    open func setUpView() {
        addSubview(contentView)
        addSubview(deleteBtn)
        let gesture = UITapGestureRecognizer(target: self, action: #selector(touchCell))
        addGestureRecognizer(gesture)
    }
    
    @objc func touchDelete() {
        delegate?.didTouchDelete(self, didDeleteItemAt: index)
    }
    
    @objc func touchCell() {
        delegate?.didTouch(self, didSelectItemAt: index)
    }
    
    func startShake() {
        guard let _ = contentView.layer.animation(forKey: "transform.rotation") else {
            contentView.layer.add(rotationAni, forKey: "transform.rotation")
            return
        }
    }
    
    func stopShake() {
        contentView.layer.removeAllAnimations()
    }
    
}
