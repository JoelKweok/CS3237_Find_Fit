from flask import Flask, request, render_template
from flask_restful import Api, Resource
from flask_jsonpify import jsonify
from flask_cors import CORS
import numpy as np
import tensorflow as tf
import pickle

def get_prediction(model, sample):
    reference = {0: "Running", 1: "Push ups", 2: "Skipping"}
    predictions = model.predict(sample)
    return reference[np.argmax(predictions)]

app = Flask(__name__)
api = Api(app)
CORS(app)
data = []

@app.route('/', methods=['GET', 'POST'])
def index():
    return render_template('index.html')

class Prediction(Resource):
    def post(self, data):
        """
        Handles post request for prediction results.
        Args:
            data: ...
        """
        #determine model chosen by user
        values = request.get_json()
        if(values[0]!=0):
            print("{0:.3f}s/10 left!".format(len(data)*0.3333))
            values = np.array(values)
            data.append(values)
            
        if len(data) == 33:
            np_data = np.array([data])
            np_data = np.reshape(np_data, -1)
            
            np_data = np.array([np_data])
            np_data = project_windows(np_data.T, pcas, mean).T

            print("--------------- END -------------------")
            activity = get_prediction(model, np_data)
            data= []
            if activity == None:
                return {"success:": "False", "activity": "NAN"}
            else:
                return {"success": "True", "activity": activity}
            

class haha(Resource):
    def get(self):
        """
        Test function.
        Args:
            None
        """
        return {"hehe":"hoho"}

api.add_resource(Prediction, '/api/v1/predict/<data>')
api.add_resource(haha, '/api/v1/predict/laugh')

if __name__ == '__main__':
    app.run(host="0.0.0.0", port="11000")
