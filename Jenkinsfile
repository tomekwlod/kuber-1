pipeline {

    agent any

    stages {
        stage('Step 1') {
            steps{
                sh "echo 'test 1...'"
                // sh "docker rmi $registry:latest"
            }
        }
        stage('Step 2') {
            steps{
                sh "/bin/sh jenkins/test001/step2.sh"
                // sh "docker rmi $registry:latest"
            }
        }
        stage('Step 3') {
            steps{
                sh "/bin/bash jenkins/test001/step3.sh"
                // sh "docker rmi $registry:latest"
            }
        }

    }
}
