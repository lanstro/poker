var app = app || {};

app.ChatView = Backbone.View.extend({
	el: '#chat_box',
	initialize: function(){
		this.render();
		this.listenTo(app.pubSub, "messageReceived", this.addMessage);
		this.setupDispatcher();
	},
	events: {
		'submit #input': "submitted",
	},
	render: function(){
		this.$el.html( $('#chat_template').html() );
		return this;
	},
	
	addMessage: function(data){
		var $log = $('#log');
		console.log(JSON.stringify(data));
		$log.val($log.val()+data.user+": "+data.broadcast+"\n");
		while($log[0].scrollHeight > 3000){
			var $str = $log.val();
			$log.val($str.substring($str.indexOf('\n')+1));
		}
		$log.scrollTop($log[0].scrollHeight - $log.height());
	},
	
	setupDispatcher: function(){
		if(!app.dispatcher){
			app.dispatcher = app.dispatcher || new WebSocketRails($('#table').data('uri'));
			app.dispatcher = app.dispatcher.subscribe($("#table").data("table_id")+'_chat');
		}
		app.dispatcher.sendMessage = function (msg){
			app.dispatcher.trigger('client_send_message', {user: "test user", broadcast: msg});
		};
	},
	
	submitted: function(e){
		e.preventDefault();
		var msg = $("#message_input").val();
		if(msg.length < 1){
			return;
		}
		app.dispatcher.sendMessage(msg);
		$("#message_input").val('');
		return;  
	},
	

	

});