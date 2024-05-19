package com.comercio.petsphere.controller

import android.media.Image
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.comercio.petsphere.ui.theme.PetSphereTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            PetSphereTheme {

                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    MainScreen()
                }
            }
        }
    }
}

@Composable
fun MainScreen() {
    Box(
        modifier = Modifier.fillMaxSize()
    ) {
        
        Greeting("Pet Sphere")
        FloatingActionButtons()

    }
}

@Composable
fun Greeting(name: String, modifier: Modifier = Modifier) {
    Box(
        contentAlignment = Alignment.TopCenter,
        modifier = modifier.fillMaxSize()
    )
    {

        Text(

            text = "Bem vindos ao $name!",
            modifier = modifier
        )
    }
}
@Composable
fun Image(){
    Box (){

    }
}

@Composable
fun FloatingActionButtons() {
    Box (
        contentAlignment = Alignment.BottomEnd,
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Column(

            verticalArrangement = Arrangement.spacedBy(16.dp),
            horizontalAlignment = Alignment.End,

            modifier = Modifier
                .padding(6.dp)
        ) {
            FloatingActionButton(
                onClick = { /* TODO: Handle Perfil click */ },
                modifier = Modifier.align(Alignment.End)
            ) {
                Text(text = "Perfil", modifier = Modifier.padding(18.dp))
            }
            FloatingActionButton(
                onClick = { /* TODO: Handle Nutrição click */ },
                modifier = Modifier.align(Alignment.End)
            ) {
                Text(text = "Exercícios", modifier = Modifier.padding(8.dp))
            }
            FloatingActionButton(
                onClick = { /* TODO: Handle Veterinário click */ },
                modifier = Modifier.align(Alignment.End)
            ) {
                Text(text = "Veterinário", modifier = Modifier.padding(8.dp))
            }
            FloatingActionButton(
                onClick = { /* TODO: Handle Nutrição click */ },
                modifier = Modifier.align(Alignment.End)
            ) {
                Text(text = "Nutrição", modifier = Modifier.padding(18.dp))
            }


        }
    }
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    PetSphereTheme {
        MainScreen()
    }
}
