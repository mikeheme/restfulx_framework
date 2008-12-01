package org.ruboss.services.mock {
  import flash.utils.Dictionary;
  import flash.utils.getQualifiedClassName;
  
  import mx.rpc.IResponder;
  import mx.rpc.events.ResultEvent;
  
  import org.ruboss.Ruboss;
  import org.ruboss.controllers.ServicesController;
  import org.ruboss.services.http.XMLHTTPServiceProvider;
  
  public class MockXMLHTTPServiceProvider extends XMLHTTPServiceProvider {

    public static const ID:int = ServicesController.generateId();
    
    private static var data:Dictionary;
            
    public override function get id():int {
      return ID;
    }
	
  	public function MockXMLHTTPServiceProvider() {
  	  super();
  	  data = new Dictionary;
  	}

    public function loadTestData(dataSets:Object):void {
      Ruboss.log.debug("loading test data for MockHTTPServiceProvider");
      for (var dataSetName:String in dataSets) {
        Ruboss.log.debug("loading test data for :" + dataSetName);
        data[dataSetName] = dataSets[dataSetName];
      }  
    }

    public override function index(object:Object, responder:IResponder, metadata:Object = null, nestedBy:Array = null):void {
      var fqn:String = getQualifiedClassName(object);
      var controllerName:String = state.controllers[fqn];
      
      Ruboss.log.debug("attempting to index: " + fqn + ", mapped to: " + controllerName);
      responder.result(new ResultEvent(ResultEvent.RESULT, false, false, data[controllerName]));
    }

    public override function show(object:Object, responder:IResponder, metadata:Object = null, nestedBy:Array = null):void {
      var fqn:String = getQualifiedClassName(object);

      Ruboss.log.debug("attempting to show :" + fqn);
      
      var marshalled:XML = XML(Ruboss.serializers.xml.marshall(object));
      marshalled.appendChild(<id>{object["id"]}</id>);
      responder.result(new ResultEvent(ResultEvent.RESULT, false, false, marshalled));
    }
  
    public override function create(object:Object, responder:IResponder, metadata:Object = null, nestedBy:Array = null):void {
      var fqn:String = getQualifiedClassName(object);
      
      Ruboss.log.debug("attempting to create :" + fqn);
      
      var marshalled:XML = XML(Ruboss.serializers.xml.marshall(object));
      // IDs are not serialized but are required in responses
      marshalled.appendChild(<id>{int(Math.abs(Math.random() * 100) + Math.abs(Math.random()) + 1)}</id>);      
      responder.result(new ResultEvent(ResultEvent.RESULT, false, false, marshalled));
    }
    
    public override function update(object:Object, responder:IResponder, metadata:Object = null, nestedBy:Array = null):void {
      var fqn:String = getQualifiedClassName(object);

      Ruboss.log.debug("attempting to update :" + fqn);
      
      var marshalled:XML = XML(Ruboss.serializers.xml.marshall(object));
      marshalled.appendChild(<id>{object["id"]}</id>);
      responder.result(new ResultEvent(ResultEvent.RESULT, false, false, marshalled));
    }
    
    public override function destroy(object:Object, responder:IResponder, metadata:Object = null, nestedBy:Array = null):void {
      var fqn:String = getQualifiedClassName(object);

      Ruboss.log.debug("attempting to destroy :" + fqn);
      
      var marshalled:XML = XML(Ruboss.serializers.xml.marshall(object));
      marshalled.appendChild(<id>{object["id"]}</id>);
      responder.result(new ResultEvent(ResultEvent.RESULT, false, false, marshalled));     
    }
  }
}
