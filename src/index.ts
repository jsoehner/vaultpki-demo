interface User {
  id: number;
  name: string;
  email: string;
}

const greetUser = (user: User): string => {
  return `Hello, ${user.name}! Your ID is ${user.id}.`;
};

const newUser: User = {
  id: 1,
  name: "Developer",
  email: "dev@example.com"
};

console.log(greetUser(newUser));