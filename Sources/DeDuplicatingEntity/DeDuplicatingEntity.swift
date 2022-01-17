//  DeDuplicatingEntity.swift
//  Created by Victor Hudson on 1/11/22.
//

import Foundation
import CoreData


/// Protocol that adds to ability to quickly deduplicate NSManagedObject instances.
public protocol DeDuplicatingEntity: NSManagedObject {
    
    
    /// All conforming types to be deduplicated must have a `uuid: UUID` property declared in your model with a valid UUID. This is used to ensure multiple devices always choose to delete and keep the same copies of entities.
    var uuid: UUID? { get set }
    
    
    /// Use this method to handle how your entities resolve relationships for deletion candidates to avoid orphan relationship objects.
    ///
    ///
    /// This is the place to move all existing relationships to the destination entity or handle them in other a ways that best suit your model.
    ///
    /// You may leave an empty stub for this method on your entity if you don't have any relationship issues to resolve.
    /// - Parameters:
    ///   - destination: another instance of the entity that will be the one kept after deduplication.
    func moveRelationships(to destination: Self)
}

public extension DeDuplicatingEntity {
    /**
     Deduplicates entities of type using a provided property for duplicate identification.
     
     Call this method on the entity Type at an appropriate time and place in your application to deduplicate it's instances.
     
     
     The context should be of `NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType` so all work occurs in a background thread.
     
        - Parameters:
            - property: the property of the entities used to identify them as duplicates
            - context: a managed object context to work in.
     
     - Important: The key parameter passed in must represent a `String` type property on your entity.
     
     
     Example:
     ~~~
     
     func deduplicate() {
         context.perform {
            MyNSManagedObjectSubclass.deduplicateBy(property: "name", in: context)
            // Deduplicate other types here....
         }
     }
     // save context
     do {
        try context.save()
     } catch {
        let error = error as NSError
        print("Failed to save Context: \(error)")
     }
     ~~~
     
     */
    static func deduplicateBy(property: String, in context: NSManagedObjectContext) {
//        print("Deduplicating: \(Self.entity().name ?? "No Type Found") by: \(property)")
//        print("Duplicates found: \(Self.duplicatedValuesOf(propertyName: property, in: context))")
        for value in Self.duplicatedValuesOf(propertyName: property, in: context) {
//            print("Deduplicating: \(value)")
            // fetch all entities with this value in propertyName
            var entities = Self.entitiesWithValue(value, forKey: property, in: context)
            
            // Pick the first entity as the winner.
            let winner = entities.first!
            entities.removeFirst()
            
            // handle the relationships of the losers and delete them.
            for entity in entities {
                entity.moveRelationships(to: winner)
                context.delete(entity)
            }
        }
        // save context
        do {
            try context.save()
        } catch {
            let error = error as NSError
            print("Failed to save Context: \(error)")
        }
    }
}

private extension DeDuplicatingEntity {
    
    /// Creates an array of the duplicated property values for a given property name on the provided entity type.
    /// - Parameters:
    ///   - propertyName: the name of the property to check for duplicated values
    ///   - entity: the entity type being checked for duplicate instances
    /// - Returns: an array of the values duplicated in the property of the given entity
    static func duplicatedValuesOf(propertyName: String, in context: NSManagedObjectContext) -> [String] {
//        print("duplicatedValuesOf(propertyName: \(propertyName), in context: NSManagedObjectContext)")
        guard let entityName = Self.entity().name else {
            print("Unable to find Entity")
            return []
        }
        
//        print("Looking for duplicated values of property: \"\(propertyName)\" in entity: \"\(entityName)\"")
        
        // We need an attribute description for the fetch request
        // We are searching the entities of entityType to be deduplicated for all of the
        // values in the property of the entityType that we will use to determine duplicates
        guard let attributeDescription = Self.entity().propertiesByName[propertyName] as? NSAttributeDescription else {
            print("Error finding Entity: \(entityName) with property name: \(propertyName) in persistent store")
            return []
        }
        
//        print("Attribute Description: \(attributeDescription)")
        // We also need a count expression for the fetch request
        // This will tell us the number of times that each value in
        // the property of the entity in question occurs
//        let expressionString = "count:\(propertyName)"
        let expressionString = "count:(\(propertyName))"
        let countExpression = NSExpression(format: expressionString)
//        print("154")

        let countExpressionDescription = NSExpressionDescription()
        countExpressionDescription.name = "count"
        countExpressionDescription.expression = countExpression
        countExpressionDescription.expressionResultType = NSAttributeType.integer64AttributeType
            
        
//        print("Expression String: \(expressionString)")
        // Build the fetch request with the attribute description
//        let fecthRequest2 = Self.fetchRequest()
        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: entityName)
        fetchRequest.includesPendingChanges = false
        fetchRequest.fetchBatchSize = 1000
        fetchRequest.propertiesToFetch = [attributeDescription, countExpressionDescription]
        fetchRequest.propertiesToGroupBy = [attributeDescription]
        fetchRequest.resultType = .dictionaryResultType
        
        // We'll store all of the property values in an array of dictionaries
        // Each dictionary will have a key representing a propertyValue
        // that corresponds to an integer count of its occurrences
        var countDictionaries: [NSDictionary]
        do {
            // Perform the fetch request
            try countDictionaries = context.fetch(fetchRequest)
//            try countDictionaries = self.context?.execute(fetchRequest) as! Array<Dictionary<String,AnyObject>>
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            print("Unresolved error \(error)")//\(error.userInfo)
            abort()
        }
        
        // Return array of values with a count > 1
        return countDictionaries.filter({ ($0["count"] as! Int) > 1 }).map({ $0[propertyName] }) as! [String]
    }
    
    static func entitiesWithValue(_ value: String,
                                  forKey key: String,
                                  in context: NSManagedObjectContext) -> [Self] {
        let fetchRequest = Self.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "uuid", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "%K = %@", key, value)
        
        guard let duplicates = try? context.fetch(fetchRequest) as? [Self] else {
            print("No Results found")
            return []
        }
        return duplicates
    }
}

