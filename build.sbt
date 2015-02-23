import NativePackagerKeys._
name := """hello-play"""


version := "1.0-SNAPSHOT"

lazy val root = (project in file(".")).enablePlugins(PlayScala)

scalaVersion := "2.11.1"

libraryDependencies ++= Seq(
  jdbc,
  anorm,
  cache,
  ws
)

maintainer in Docker := "Mirai Watanabe <ababup1192@gmail.com>"

dockerExposedPorts in Docker := Seq(9000,  50080)
