import tensorflow as tf
import numpy as np

def get_model(model_name='./cnn_model'):
    return tf.keras.models.load_model(model_name)

def convert_to_model_input(json_data):
    model_input = []
    for i in range(33):
        temp_row = []
        temp_row.append(json_data[str(i)]["ax"])
        temp_row.append(json_data[str(i)]["ay"])
        temp_row.append(json_data[str(i)]["az"])
        temp_row.append(json_data[str(i)]["gx"])
        temp_row.append(json_data[str(i)]["gy"])
        temp_row.append(json_data[str(i)]["gz"])
        model_input.append(np.array(temp_row))
    return np.array(model_input)

def get_prediction(model, sample):
    reference = {0: "Running", 1: "Push ups", 2: "Skipping"}
    predictions = model.predict(np.array([sample]))
    exercise_id = np.argmax(predictions)
    return exercise_id, reference[exercise_id]
