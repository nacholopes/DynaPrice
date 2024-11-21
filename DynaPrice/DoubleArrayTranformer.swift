import Foundation
import CoreData

@objc(DoubleArrayTransformer)
class DoubleArrayTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSArray.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let array = value as? NSArray else { return nil }
        
        // Convert NSArray to [Double] before archiving
        let doubleArray = array.compactMap { ($0 as? NSNumber)?.doubleValue }
        
        let data = try? NSKeyedArchiver.archivedData(
            withRootObject: doubleArray,
            requiringSecureCoding: true
        )
        return data
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        
        let allowedClasses = [NSArray.self, NSNumber.self]
        
        if let doubles = try? NSKeyedUnarchiver.unarchivedObject(
            ofClasses: allowedClasses,
            from: data
        ) as? [Double] {
            // Convert [Double] back to NSArray
            return NSArray(array: doubles)
        }
        return nil
    }
    
    static func register() {
        ValueTransformer.setValueTransformer(
            DoubleArrayTransformer(),
            forName: NSValueTransformerName("DoubleArrayTransformer")
        )
    }
}
