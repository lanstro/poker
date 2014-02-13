var app = app || {};

app.CardView = Backbone.View.extend({
	tag: 'div',
	className: 'card',
	
	initialize: function(){
		_.templateSettings = {
			interpolate: /\<\@\=(.+?)\@\>/gim,
			evaluate: 	 /\<\@(.+?)\@\>/gim,
			escape: 		 /\<\@\-(.+?)\@\>/gim
		};
		_.bindAll(this, 'dragStarted', 'droppedOn');
		this.template=_.template($('#card_template').html());
		this.listenTo(this.model, "change:val", this.render);
		this.listenTo(this.model, "change:highlighted", this.checkHighlighted);
	},
	
	events: {
		'click': 'clicked',
		'dragstart': 'dragStarted',
		'drop': 'droppedOn',
		'dragenter': 'dragEntered',
		'dragleave': 'dragLeft',
		'dragover': 'draggedOver',
		'dragend': 'dragEnded'
	},
	
	switchModel: function(newAttributes){
		this.model.set(newAttributes);
		this.model.set({highlighted: false});
	},
	
	dragStarted: function(arg){
		if(this.isBlank()){
			arg.preventDefault();
			return;
		}
		if(app.statusModel.get("status") < DEALING || app.statusModel.get("status") > ALMOST_SHOWDOWN)
			return;
		this.model.set("highlighted", true);
		arg.originalEvent.dataTransfer.setData('text/html', this.model.get("val"));		
	},
	
	draggedOver: function(e) {
		e.preventDefault(); 
		return false;
	},
	
	dragEnded: function(e){
		e.stopPropagation();
		e.preventDefault();
		return false;
	},
	
	droppedOn: function(arg){
		this.eventTracker(arg);
		var data = arg.originalEvent.dataTransfer.getData('text/html');
		arg.stopPropagation(); // stops the browser from redirecting.
		arg.preventDefault();
		data=parseInt(data)
		if(data == this.model.get("val"))
			return;
		app.pubSub.trigger("dragDropFinished", data, this);
	},
	
	dragEntered: function(arg){
		arg.preventDefault();
		if(app.statusModel.get("status") < DEALING || app.statusModel.get("status") > ALMOST_SHOWDOWN)
			return;
		this.$el.children(":first").addClass("drag_highlighted");
	},
	
	dragLeft: function(arg){
		if(app.statusModel.get("status") < DEALING || app.statusModel.get("status") > ALMOST_SHOWDOWN)
			return;
		this.$el.children(":first").removeClass("drag_highlighted");
	},
	
	isBlank: function(){
		return this.model.get("human_description") === "blank";
	},
	
	checkHighlighted: function(){
		if(this.model.get("highlighted"))
			this.$el.children(":first").addClass("highlighted");
		else
		  this.$el.children(":first").removeClass("highlighted");
	},
	
	eventTracker: function(arg2){
		if(arg2){
			var cache=[];
			console.log("arg was "+JSON.stringify(arg2, function(key, value) {
				if (typeof value === 'object' && value !== null) {
					if (cache.indexOf(value) !== -1) {
					// Circular reference found, discard key
						return;
					}
				// Store value in our collection
					cache.push(value);
				}
				return value;
			}));
		}
	},
	
	clicked: function(obj){
		if(app.statusModel.get("status") < DEALING || app.statusModel.get("status") > ALMOST_SHOWDOWN)
			return;
	
		if(this.isBlank()){
			if( $(".highlighted").length > 0 )
				app.pubSub.trigger("blankClicked", this);
		}
		else
			this.toggleHighlighted();
	},
	
	toggleHighlighted: function(){
		this.model.set('highlighted', !this.model.get('highlighted'));
	},

	render: function(){
		this.$el.empty();
		this.$el.html(this.template({human_description: this.model.get("human_description")}));
		this.checkHighlighted();
		return this;
	}
	
});