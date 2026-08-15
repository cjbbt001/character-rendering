using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public class PreviewObject : MonoBehaviour {
    public bool AutoRotate = false;
    public float sensity = 1.0f;
    Vector3 mPrevPos = Vector3.zero;
    Vector3 mPosDelta = Vector3.zero;
	// Use this for initialization
	void Start () {
        if (Mouse.current != null)
        {
            mPrevPos = Mouse.current.position.ReadValue();
        }
    }

	// Update is called once per frame
	void Update () {
        Mouse mouse = Mouse.current;
        if (mouse == null)
        {
            return;
        }

        Vector3 mousePosition = mouse.position.ReadValue();

        if (AutoRotate)
        {
            mPosDelta = mousePosition - mPrevPos;
            transform.Rotate(Vector3.up, sensity, Space.World);
        }
        else {
            if (mouse.leftButton.isPressed)
            {
                mPosDelta = mousePosition - mPrevPos;
                transform.Rotate(Vector3.up, Vector3.Dot(mPosDelta, Camera.main.transform.right) * sensity * 0.1f, Space.World);
            }
        }
        mPrevPos = mousePosition;
	}
}
