/*************************************************************************
 * Copyright 2008, Ruboss Technology Corporation.
 *
 * This is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License v3 as
 * published by the Free Software Foundation.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License v3 for more details.
 *
 * You should have received a copy of the GNU General Public
 * License v3 along with this software; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA, or see the FSF site: http://www.fsf.org.
 **************************************************************************/
package org.ruboss.services.air {
  import flash.data.SQLConnection;
  import flash.data.SQLStatement;
  import flash.filesystem.File;
  import flash.utils.Dictionary;
  import flash.utils.describeType;
  import flash.utils.getQualifiedClassName;
  
  import mx.rpc.IResponder;
  import mx.rpc.events.ResultEvent;
  import mx.utils.ObjectUtil;
  
  import org.ruboss.Ruboss;
  import org.ruboss.controllers.RubossModelsController;
  import org.ruboss.models.ModelsCollection;
  import org.ruboss.models.ModelsStateMetadata;
  import org.ruboss.services.IServiceProvider;
  import org.ruboss.services.ServiceManager;
  import org.ruboss.utils.RubossUtils;

  public class AIRServiceProvider implements IServiceProvider {
    
    public static const ID:int = ServiceManager.generateId();

    private static var types:Object = {
      "int" : "INTEGER",
      "uint" : "INTEGER",
      "Boolean" : "BOOLEAN",
      "String" : "TEXT",
      "Number" : "DOUBLE",
      "Date" : "DATE",
      "DateTime" : "DATETIME"
    }
    
    private var state:ModelsStateMetadata;
    
    private var sql:Dictionary;
        
    private var connection:SQLConnection;

    public function AIRServiceProvider(controller:RubossModelsController) {
      this.state = controller.state;
      
      var databaseName:String = Ruboss.airDatabaseName;
      var dbFile:File = File.userDirectory.resolvePath(databaseName + ".db");

      this.sql = new Dictionary;
      this.connection = new SQLConnection;
      
      for each (var model:Class in state.models) {
        var fqn:String = getQualifiedClassName(model);
        sql[fqn] = new Dictionary;          
      }
      
      state.models.forEach(function(elm:Object, index:int, array:Array):void {
        extractMetadata(elm);
      });
      
      initializeConnection(databaseName, dbFile);
    }
    
    private function isNotValidType(node:XML):Boolean {
      return (RubossUtils.isHasMany(node) || RubossUtils.isHasOne(node));
    }
    
    private function extractMetadata(model:Object):void {
      var tableName:String = RubossUtils.getResourceController(model);
      var modelName:String = getQualifiedClassName(model);
      
      var createStatement:String = "CREATE TABLE IF NOT EXISTS " + tableName + "(";
      
      var insertStatement:String = "INSERT INTO " + tableName + "(";
      var insertParams:String = "";
      
      var updateStatement:String = "UPDATE " + tableName + " SET ";
      
      for each (var node:XML in describeType(model)..accessor) {
        if (node.@declaredBy == modelName) {
          var snakeName:String = RubossUtils.toSnakeCase(node.@name);
          var type:String = node.@type;
          
          // skip collections
          if (isNotValidType(node) || type == "org.ruboss.models::ModelsCollection") continue;
                      
          if (sql[type] && RubossUtils.isBelongsTo(node)) {
            snakeName = snakeName + "_id";
          }
          
          createStatement += snakeName + " " +  getSQLType(node) + ", ";
          insertStatement += snakeName + ", ";
          insertParams += ":" + snakeName + ", ";
          updateStatement += snakeName + "=:" + snakeName + ","; 
        }
      }
      
      createStatement += "id INTEGER PRIMARY KEY AUTOINCREMENT)";      
      sql[modelName]["create"] = createStatement;
            
      insertParams = insertParams.substr(0, insertParams.length - 2);
      insertStatement = insertStatement.substr(0, 
        insertStatement.length - 2) + ") VALUES(" + insertParams + ")";
      sql[modelName]["insert"] = insertStatement;
      
      updateStatement = updateStatement.substring(0, updateStatement.length - 1);
      updateStatement += " WHERE id={id}";
      sql[modelName]["update"] = updateStatement;

      var deleteStatement:String = "DELETE FROM " + tableName + " WHERE id={id}";
      sql[modelName]["delete"] = deleteStatement;
      
      var selectStatement:String = "SELECT * FROM " + tableName;
      sql[modelName]["select"] = selectStatement;
    }

    private function getSQLType(node:XML):String {
      var type:String = node.@type;
      var result:String = types[type];
      if (sql[type]) {
        return types["int"];
      } else if (RubossUtils.isDateTime(node)) {
        return types["DateTime"];
      } else {
        return (result == null) ? types["String"] : result; 
      }
    }
    
    private function initializeConnection(databaseName:String, 
      databaseFile:File):void {
      connection.open(databaseFile);
      for (var modelName:String in sql) {
        var statement:SQLStatement = getSQLStatement(sql[modelName]["create"]);
        statement.execute();
      }
    }
    
    private function getSQLStatement(statement:String):SQLStatement {
      var sqlStatement:SQLStatement = new SQLStatement;
      sqlStatement.sqlConnection = connection;
      sqlStatement.text = statement;
      return sqlStatement;     
    }
    
    private function invokeResponder(responder:IResponder, 
			result:Object):void {
      var event:ResultEvent = new ResultEvent("QUERY_COMPLETE", false, 
        false, result);
      if (responder != null) {
        responder.result(event);
      }
    }
    
    private function isValidTypeAndName(type:String, name:String):Boolean {   
      // skip collections and ids, ids are auto generated
      return !(type == "org.ruboss.models::ModelsCollection" || name == "id");      
    }

    public function get id():int {
      return ID;
    }
    
    public function marshall(object:Object, metadata:Object = null):Object {
      return object;
    }

    public function unmarshall(object:Object):Object {
      return object;
    }

    public function peek(object:Object):String {
      return null;
    }
    
    public function error(object:Object):Boolean {
      return false;
    }
    
    public function index(clazz:Object, responder:IResponder, metadata:Object = null, nestedBy:Array = null):void {
      var fqn:String = getQualifiedClassName(clazz);
      var statement:SQLStatement = getSQLStatement(sql[fqn]["select"]);
      statement.execute();
      var data:Array = statement.getResult().data;
      
      var result:Array  = new Array;
      for each (var object:Object in data) {
        var model:Object = new clazz();
        model["id"] = object["id"];
        
        var objectMetadata:XML = describeType(model);        
        for (var property:String in object) {
          var targetName:String = property;
          
          if (targetName == "id") continue;
          
          var value:Object = object[property];
          
          var isRef:Boolean = false;
          // if we got a node with a name that terminates in "_id" we check to see if
          // it's a model reference       
          if (targetName.search(/.*_id$/) != -1) {
            var checkName:String = RubossUtils.toCamelCase(targetName.replace(/_id$/, ""));
            if (state.keys[checkName]) {
              targetName = checkName;
              isRef = true;
            }
          } else {
            targetName = RubossUtils.toCamelCase(targetName);
          }

          if (isRef) {
            var elementId:int = parseInt(value.toString());
            
            var ref:Object = null; 
            if (elementId != 0 && !isNaN(elementId)) {
              var key:String = state.keys[targetName];
              // key should be fqn for the targetName;
              var models:RubossModelsController = Ruboss.models;
              ref = ModelsCollection(Ruboss.models.cache[key]).withId(elementId);
            }

            // collectionName should be the same as the camel-cased name of the controller for the current node
            var collectionName:String = RubossUtils.toCamelCase(state.controllers[state.keys[fqn]]);
                
            // if we've got a plural definition which is annotated with [HasMany] 
            // it's got to be a 1->N relationship           
            if (ref != null && ref.hasOwnProperty(collectionName) &&
              ObjectUtil.hasMetadata(ref, collectionName, "HasMany")) {
              var items:ModelsCollection = ModelsCollection(ref[collectionName]);
              if (items == null) {
                items = new ModelsCollection;
                ref[collectionName] = items;
              }
              
              // add (or replace) the current item to the reference collection
              if (items.hasItem(model)) {
                items.setItem(model);
              } else {
                items.addItem(model);
              }
            // if we've got a singular definition annotated with [HasOne] then it must be a 1->1 relationship
            // link them up
            } else if (ref != null && ref.hasOwnProperty(targetName) && 
              ObjectUtil.hasMetadata(ref, targetName, "HasOne")) {
              ref[targetName] = model;
            }
            // and the reverse
            model[targetName] = ref;
          } else if (!isRef) {
            var targetType:String = getSQLType(XMLList(objectMetadata..accessor.(@name == targetName))[0]).toLowerCase();
            model[targetName] = RubossUtils.cast(targetName, targetType, value);
          }
        }
        result.push(model);
      }
      invokeResponder(responder, result);
    }
    
    // TODO implement proper select * from foo where id = object["id"]
    public function show(object:Object, responder:IResponder, metadata:Object = null, nestedBy:Array = null):void {
    }
    
    public function create(object:Object, responder:IResponder, metadata:Object = null, nestedBy:Array = null):void {
      var fqn:String = getQualifiedClassName(object);
      var statement:SQLStatement = getSQLStatement(sql[fqn]["insert"]);
      for each (var n:XML in describeType(object)..accessor) {
        if (n.@declaredBy == getQualifiedClassName(object)) {
          var localName:String = n.@name;
          var type:String = n.@type;
          var snakeName:String = RubossUtils.toSnakeCase(localName);

          if (!isValidTypeAndName(type, n.@name) || isNotValidType(n)) continue;
                      
          if (sql[type] && RubossUtils.isBelongsTo(n)) {
            snakeName = snakeName + "_id";
            var ref:Object = object[localName];
            statement.parameters[":" + snakeName] = 
              (ref == null) ? null : ref["id"];
          } else {
            statement.parameters[":" + snakeName] = 
              RubossUtils.uncast(object, localName);
          }
        }
      }
      statement.execute();
      object["id"] = statement.getResult().lastInsertRowID;
      invokeResponder(responder, object);
    }
    
    public function update(object:Object, responder:IResponder, metadata:Object = null, nestedBy:Array = null):void {
      var fqn:String = getQualifiedClassName(object);
      var statement:String = sql[fqn]["update"];
      statement = statement.replace("{id}", object["id"]);
      var sqlStatement:SQLStatement = getSQLStatement(statement);
      for each (var n:XML in describeType(object)..accessor) {
        if (n.@declaredBy == getQualifiedClassName(object)) {
          var localName:String = n.@name;
          var type:String = n.@type;
          var snakeName:String = RubossUtils.toSnakeCase(localName);

          if (!isValidTypeAndName(type, n.@name) || isNotValidType(n)) continue;
                      
          if (sql[type] && RubossUtils.isBelongsTo(n)) {
            snakeName = snakeName + "_id";
            var ref:Object = object[localName];
            sqlStatement.parameters[":" + snakeName] = 
              (ref == null) ? null : ref["id"];
          } else {
            sqlStatement.parameters[":" + snakeName] = 
              RubossUtils.uncast(object, localName);
          }
        }
      }
      sqlStatement.execute();
      invokeResponder(responder, object);
    }
    
    public function destroy(object:Object, responder:IResponder, metadata:Object = null, nestedBy:Array = null):void {
      var fqn:String = getQualifiedClassName(object);
      var statement:String = sql[fqn]["delete"];
      statement = statement.replace("{id}", object["id"]);
      getSQLStatement(statement).execute();
      invokeResponder(responder, object);
    }
  }
}