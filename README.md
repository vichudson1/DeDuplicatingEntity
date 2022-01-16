# DeDuplicatingEntity

DeDuplicatingEntity is a protocol you can add to your Core Data model types to give them the functionality to deduplicate their instances based on a property of the model type you chose at deduplication time. 

Get started by conforming your types to the `DeDuplicatingEntity` protocol. Once your model types conform to this protocol they get this functionality provided to them by the protocol extension.

All conforming types to be deduplicated must have a `uuid: UUID?` property declared in your model with a valid UUID saved to each instance. This is used to ensure multiple devices always choose to delete and keep the same copies of entities.

There is only one method you need to add to your model type. 

`func moveRelationships(to destination: MyNSManagedObjectSubclass)`

Example conformance below:
~~~
extension MyNSManagedObjectSubclass: DeDuplicatingEntity {

    func moveRelationships(to destination: MyNSManagedObjectSubclass) {
        // Use this method to handle how your entities resolve relationships 
        // for deletion candidates to avoid orphan relationship objects. 
        // This method will be called on each deletion candidate 
        // just before deletion.

        // This is the place to move all existing relationships
        // to the destination instance, the one that will be kept, 
        // or handle them in other a ways that best suit your model.

        // You may leave an empty stub for this method on your entity 
        // if you don't have any relationship issues to resolve.
    }
}
~~~

Once your types conform to the protocol deduplicating them in your persistent store only requires one method call.
`static func deduplicateBy(property: String, in context: NSManagedObjectContext)`

Call this method on the entity Type at an appropriate time and place in your application to deduplicate it's instances.

- Parameters:
     - property: the property of the entities used to identify them as duplicates
     - context: a managed object context to work in. The context should be of `NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType` so all work occurs on a background thread.

- Important: The property parameter passed in must represent a `String` type property on your entity.


Example Usage:
~~~
// Called at an appropriate time and place in your app for deduplication
func deduplicate(in context: NSManagedObjectContext) {
    context.perform {
       MyNSManagedObjectSubclass.deduplicateBy(property: "name", in: context)
       // Deduplicate other types here....
    }
    // save context
    do {
       try context.save()
    } catch {
       let error = error as NSError
       print("Failed to save Context: \(error)")
    }
}
~~~
